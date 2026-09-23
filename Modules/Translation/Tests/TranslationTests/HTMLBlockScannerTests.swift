//
//  HTMLBlockScannerTests.swift
//  Translation
//

import XCTest
@testable import Translation

final class HTMLBlockScannerTests: XCTestCase {

	func testSplitsParagraphsIntoTranslatableBlocks() {

		let html = "<p>First paragraph.</p><p>Second paragraph.</p>"
		let blocks = HTMLBlockScanner.scan(html)

		let translatable = HTMLBlockScanner.translatableInnerHTML(in: blocks)
		XCTAssertEqual(translatable.count, 2)
		XCTAssertEqual(translatable[0].innerHTML, "First paragraph.")
		XCTAssertEqual(translatable[1].innerHTML, "Second paragraph.")
	}

	func testJoinSubstitutesTranslationsAndKeepsMarkup() {

		let html = "<p>Hello</p><p>World</p>"
		let blocks = HTMLBlockScanner.scan(html)
		let ids = HTMLBlockScanner.translatableInnerHTML(in: blocks).map { $0.id }

		let joined = HTMLBlockScanner.joined(blocks, translations: [ids[0]: "你好", ids[1]: "世界"])
		XCTAssertEqual(joined, "<p>你好</p><p>世界</p>")
	}

	func testJoinKeepsOriginalWhenTranslationMissing() {

		let html = "<p>Hello</p><p>World</p>"
		let blocks = HTMLBlockScanner.scan(html)

		let joined = HTMLBlockScanner.joined(blocks, translations: [:])
		XCTAssertEqual(joined, html)
	}

	func testCodeBlocksArePassedThrough() {

		let html = "<p>Intro text.</p><pre><code>let x = 1</code></pre><p>Outro text.</p>"
		let blocks = HTMLBlockScanner.scan(html)
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: blocks)

		XCTAssertEqual(translatable.count, 2)
		XCTAssertEqual(HTMLBlockScanner.joined(blocks, translations: [:]), html)
	}

	func testImageOnlyParagraphIsNotTranslated() {

		let html = "<p><img src=\"a.png\" /></p><p>Real text.</p>"
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.count, 1)
		XCTAssertEqual(translatable[0].innerHTML, "Real text.")
	}

	func testInlineTagsStayInsideTheBlock() {

		let html = "<p>Read <a href=\"https://example.com\">this link</a> now.</p>"
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.count, 1)
		XCTAssertEqual(translatable[0].innerHTML, "Read <a href=\"https://example.com\">this link</a> now.")
	}

	func testNestedListItemsStayInsideTheOuterBlock() {

		let html = "<ul><li>Outer<ul><li>Inner</li></ul></li></ul>"
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.count, 1)
		XCTAssertEqual(translatable[0].innerHTML, "Outer<ul><li>Inner</li></ul>")
	}

	func testSiblingListItemsAreSeparateBlocks() {

		let html = "<ul><li>One</li><li>Two</li></ul>"
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.map { $0.innerHTML }, ["One", "Two"])
	}

	func testUnclosedParagraphIsStillTranslatable() {

		let html = "<p>Never closed"
		let blocks = HTMLBlockScanner.scan(html)
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: blocks)

		XCTAssertEqual(HTMLBlockScanner.joined(blocks, translations: [:]), html)
		XCTAssertEqual(translatable.map { $0.innerHTML }, ["Never closed"])
	}

	/// Feeds such as inessential.com emit `<p>` opens with no `</p>` at all. That
	/// article used to come back untranslated because no closed block was found.
	func testParagraphsWithOmittedEndTagsAreTranslatable() {

		let html = "<p>First paragraph.\n\n<p>Second paragraph.\n\n<p>Third paragraph."
		let blocks = HTMLBlockScanner.scan(html)
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: blocks)

		XCTAssertEqual(translatable.count, 3)
		XCTAssertEqual(translatable.map { $0.innerHTML.trimmingCharacters(in: .whitespacesAndNewlines) },
					   ["First paragraph.", "Second paragraph.", "Third paragraph."])
		XCTAssertEqual(HTMLBlockScanner.joined(blocks, translations: [:]), html)

		var translations = [Int: String]()
		for (offset, block) in translatable.enumerated() {
			translations[block.id] = ["第一段。", "第二段。", "第三段。"][offset]
		}
		XCTAssertEqual(HTMLBlockScanner.joined(blocks, translations: translations),
					   "<p>第一段。<p>第二段。<p>第三段。")
	}

	func testHeadingEndsAnOpenParagraph() {

		let html = "<p>Intro text.<h2>Heading</h2><p>Body text."
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.map { $0.innerHTML }, ["Intro text.", "Heading", "Body text."])
	}

	func testHeadingsAndQuotesAreTranslatable() {

		let html = "<h2>A heading</h2><blockquote>A quote</blockquote>"
		let translatable = HTMLBlockScanner.translatableInnerHTML(in: HTMLBlockScanner.scan(html))

		XCTAssertEqual(translatable.map { $0.innerHTML }, ["A heading", "A quote"])
	}
}
