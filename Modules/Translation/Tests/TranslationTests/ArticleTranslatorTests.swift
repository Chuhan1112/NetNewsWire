//
//  ArticleTranslatorTests.swift
//  Translation
//

import Foundation
import XCTest
@testable import Translation

private struct EchoingTranslator: ChatCompletionTransport {

	/// Replies with the first translatable-looking piece of each request, prefixed.
	func complete(_ request: ChatCompletionRequest) async throws -> String {
		let user = request.messages.last?.content ?? ""
		let body = user.components(separatedBy: ":\n\n").last ?? user
		let parts = body.components(separatedBy: "\n\n%%\n\n")
		return parts.map { "[T] " + $0 }.joined(separator: "\n\n%%\n\n")
	}
}

private struct CountingTransport: ChatCompletionTransport {

	let recorder: ReplyRecorder

	func complete(_ request: ChatCompletionRequest) async throws -> String {
		let index = await recorder.record(request)
		return ["标题", "一\n\n%%\n\n二"][min(index, 1)]
	}
}

private actor ReplyRecorder {

	private(set) var requests: [ChatCompletionRequest] = []

	func record(_ request: ChatCompletionRequest) -> Int {
		requests.append(request)
		return requests.count - 1
	}
}

final class ArticleTranslatorTests: XCTestCase {

	func testTranslatesTitleAndBodyTogether() async throws {

		let translator = ArticleTranslator(
			translator: Translator(
				configuration: TranslationConfiguration(
					baseURL: URL(string: "http://127.0.0.1:18000/v1")!,
					model: "Hy-MT2-1.8B-4bit"
				),
				transport: EchoingTranslator()
			)
		)

		let result = try await translator.translate(title: "Hello World", bodyHTML: "<p>One</p><p>Two</p>")

		XCTAssertEqual(result.title, "[T] Hello World")
		XCTAssertEqual(result.bodyHTML, "<p>[T] One</p><p>[T] Two</p>")
	}

	func testCodeBlocksSurviveTranslation() async throws {

		let translator = ArticleTranslator(
			translator: Translator(
				configuration: TranslationConfiguration(
					baseURL: URL(string: "http://127.0.0.1:18000/v1")!,
					model: "Hy-MT2-1.8B-4bit"
				),
				transport: EchoingTranslator()
			)
		)

		let html = "<p>Intro</p><pre><code>let x = 1</code></pre>"
		let result = try await translator.translate(title: nil, bodyHTML: html)

		XCTAssertEqual(result.bodyHTML, "<p>[T] Intro</p><pre><code>let x = 1</code></pre>")
		XCTAssertNil(result.title)
	}

	func testTitleAndBodyAreRequestedSeparately() async throws {

		let recorder = ReplyRecorder()
		let translator = ArticleTranslator(
			translator: Translator(
				configuration: TranslationConfiguration(
					baseURL: URL(string: "http://127.0.0.1:18000/v1")!,
					model: "Hy-MT2-1.8B-4bit"
				),
				transport: CountingTransport(recorder: recorder)
			)
		)

		let result = try await translator.translate(title: "Title", bodyHTML: "<p>One</p><p>Two</p>")

		XCTAssertEqual(result.title, "标题")
		XCTAssertEqual(result.bodyHTML, "<p>一</p><p>二</p>")

		let requests = await recorder.requests
		XCTAssertEqual(requests.count, 2)
	}

	func testCacheStoresAndReturnsTranslations() async {

		let cache = TranslationCache(capacity: 2)
		let first = ArticleTranslation(title: "标题", bodyHTML: "<p>一</p>")

		await cache.store(first, forKey: "article-1")
		let fetched = await cache.translation(forKey: "article-1")
		XCTAssertEqual(fetched, first)

		await cache.store(ArticleTranslation(bodyHTML: "<p>二</p>"), forKey: "article-2")
		await cache.store(ArticleTranslation(bodyHTML: "<p>三</p>"), forKey: "article-3")

		// article-1 should have been evicted.
		XCTAssertNil(await cache.translation(forKey: "article-1"))
		XCTAssertNotNil(await cache.translation(forKey: "article-3"))
	}
}
