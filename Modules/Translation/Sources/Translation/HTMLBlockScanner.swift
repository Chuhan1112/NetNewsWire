//
//  HTMLBlockScanner.swift
//  Translation
//

import Foundation

/// Splits article HTML into blocks that can be translated independently, so the
/// surrounding markup, images, and code survive the round trip untouched.
///
/// Anything the scanner does not recognize is passed through verbatim, which keeps
/// odd or malformed feed HTML from being silently rewritten.
public struct HTMLBlockScanner: Sendable {

	public struct TranslatableBlock: Sendable, Equatable {

		public let id: Int
		public let openTag: String
		public let closeTag: String
		public let innerHTML: String

		public init(id: Int, openTag: String, closeTag: String, innerHTML: String) {
			self.id = id
			self.openTag = openTag
			self.closeTag = closeTag
			self.innerHTML = innerHTML
		}
	}

	public enum Block: Sendable, Equatable {
		case translatable(TranslatableBlock)
		case passthrough(String)
	}

	/// Tags whose inner HTML is worth translating.
	private static let translatableTags: Set<String> = [
		"p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote",
		"figcaption", "td", "th", "dd", "dt", "caption", "summary"
	]

	/// Tags whose contents must never be translated.
	private static let opaqueTags: Set<String> = [
		"pre", "code", "script", "style", "kbd", "samp", "textarea", "svg", "math"
	]

	private static let voidTags: Set<String> = [
		"br", "img", "hr", "input", "meta", "link", "source", "col", "area",
		"base", "embed", "param", "track", "wbr"
	]

	public static func scan(_ html: String) -> [Block] {

		var blocks: [Block] = []
		var pending = ""
		var nextID = 0

		func flushPending() {
			if !pending.isEmpty {
				blocks.append(.passthrough(pending))
				pending = ""
			}
		}

		var index = html.startIndex

		while index < html.endIndex {

			guard html[index] == "<" else {
				pending.append(html[index])
				index = html.index(after: index)
				continue
			}

			guard let tagEnd = html[html.index(after: index)...].firstIndex(of: ">") else {
				// Truncated markup — keep the rest as-is.
				pending.append(contentsOf: html[index...])
				break
			}

			let afterTag = html.index(after: tagEnd)
			let rawTag = String(html[index...tagEnd])
			let tagBody = String(html[html.index(after: index)..<tagEnd])
			let isClosing = tagBody.first == "/"
			let name = tagName(from: isClosing ? String(tagBody.dropFirst()) : tagBody)

			if !isClosing, translatableTags.contains(name),
			   let closeRange = matchingCloseTagRange(in: html, from: afterTag, name: name) {

				let innerHTML = String(html[afterTag..<closeRange.lowerBound])
				let closeTag = String(html[closeRange])
				flushPending()

				if containsTranslatableText(innerHTML) {
					blocks.append(.translatable(TranslatableBlock(id: nextID, openTag: rawTag, closeTag: closeTag, innerHTML: innerHTML)))
					nextID += 1
				} else {
					// Image-only and whitespace-only paragraphs cost a request and gain nothing.
					blocks.append(.passthrough(rawTag + innerHTML + closeTag))
				}

				index = html.index(after: closeRange.upperBound)
				continue
			}

			if !isClosing, opaqueTags.contains(name),
			   let closeRange = matchingCloseTagRange(in: html, from: afterTag, name: name) {

				let innerHTML = String(html[afterTag..<closeRange.lowerBound])
				let closeTag = String(html[closeRange])
				flushPending()
				blocks.append(.passthrough(rawTag + innerHTML + closeTag))
				index = html.index(after: closeRange.upperBound)
				continue
			}

			pending += rawTag
			index = afterTag
		}

		flushPending()
		return blocks
	}

	/// Rebuilds the document, substituting translated inner HTML where available.
	/// Blocks without a translation keep their original content.
	public static func joined(_ blocks: [Block], translations: [Int: String]) -> String {

		var out = ""
		for block in blocks {
			switch block {
			case .passthrough(let raw):
				out += raw
			case .translatable(let block):
				out += block.openTag + (translations[block.id] ?? block.innerHTML) + block.closeTag
			}
		}
		return out
	}

	/// The inner HTML of every translatable block, in document order.
	public static func translatableInnerHTML(in blocks: [Block]) -> [(id: Int, innerHTML: String)] {
		blocks.compactMap { block in
			if case .translatable(let t) = block {
				return (t.id, t.innerHTML)
			}
			return nil
		}
	}

	// MARK: - Private

	private static func containsTranslatableText(_ html: String) -> Bool {
		plainText(html).rangeOfCharacter(from: .letters) != nil
	}

	private static func plainText(_ html: String) -> String {

		var out = ""
		var index = html.startIndex

		while index < html.endIndex {
			if html[index] == "<" {
				if let tagEnd = html[html.index(after: index)...].firstIndex(of: ">") {
					index = html.index(after: tagEnd)
					continue
				}
				break
			}
			out.append(html[index])
			index = html.index(after: index)
		}
		return out
	}

	private static func tagName(from tagBody: String) -> String {

		var name = ""
		for character in tagBody {
			if character == "/" || character.isWhitespace || character == ">" {
				break
			}
			name.append(character)
		}
		return name.lowercased()
	}

	/// Finds the close tag matching an open tag, tolerating nested tags of the same name.
	private static func matchingCloseTagRange(in html: String, from start: String.Index, name: String) -> ClosedRange<String.Index>? {

		var depth = 0
		var index = start

		while index < html.endIndex {

			guard html[index] == "<", let tagEnd = html[html.index(after: index)...].firstIndex(of: ">") else {
				index = html.index(after: index)
				continue
			}

			let tagBody = String(html[html.index(after: index)..<tagEnd])
			let isClosing = tagBody.first == "/"
			let tagName = tagName(from: isClosing ? String(tagBody.dropFirst()) : tagBody)

			if tagName == name {
				if isClosing {
					if depth == 0 {
						return index...tagEnd
					}
					depth -= 1
				} else if !voidTags.contains(tagName), !tagBody.hasSuffix("/") {
					depth += 1
				}
			}

			index = html.index(after: tagEnd)
		}

		return nil
	}
}
