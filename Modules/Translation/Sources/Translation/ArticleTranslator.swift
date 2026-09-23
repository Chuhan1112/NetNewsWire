//
//  ArticleTranslator.swift
//  Translation
//

import Foundation

/// The translated form of one article, ready to drop into the article renderer.
public struct ArticleTranslation: Sendable, Equatable {

	public var title: String?
	public var bodyHTML: String

	public init(title: String? = nil, bodyHTML: String) {
		self.title = title
		self.bodyHTML = bodyHTML
	}
}

/// Translates an article's title and body HTML together.
public struct ArticleTranslator: Sendable {

	public let translator: Translator

	public init(translator: Translator) {
		self.translator = translator
	}

	public init(configuration: TranslationConfiguration) {
		self.init(translator: Translator(configuration: configuration))
	}

	public func translate(title: String?, bodyHTML: String) async throws -> ArticleTranslation {

		let blocks = HTMLBlockScanner.scan(bodyHTML)
		let targets = HTMLBlockScanner.translatableInnerHTML(in: blocks)
		let translator = self.translator

		async let translatedTitle = Self.translateTitle(title, translator: translator)
		async let translatedParts = translator.translate(targets.map { $0.innerHTML })

		let titleParts = try await translatedTitle
		let parts = try await translatedParts

		var translationsByID = [Int: String]()
		for (offset, part) in parts.enumerated() where offset < targets.count {
			translationsByID[targets[offset].id] = part
		}

		return ArticleTranslation(
			title: titleParts.first,
			bodyHTML: HTMLBlockScanner.joined(blocks, translations: translationsByID)
		)
	}

	private static func translateTitle(_ title: String?, translator: Translator) async throws -> [String] {
		guard let title, !title.isEmpty else {
			return []
		}
		return try await translator.translate([title])
	}
}
