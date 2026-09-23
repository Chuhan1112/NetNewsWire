//
//  TranslatorTests.swift
//  Translation
//

import Foundation
import XCTest
@testable import Translation

/// Returns a canned reply per request, in call order.
private struct FakeTransport: ChatCompletionTransport {

	let replies: [String]
	let recorder: ReplyRecorder

	init(replies: [String], recorder: ReplyRecorder = ReplyRecorder()) {
		self.replies = replies
		self.recorder = recorder
	}

	func complete(_ request: ChatCompletionRequest) async throws -> String {
		let callIndex = await recorder.record(request)
		if callIndex < replies.count {
			return replies[callIndex]
		}
		return replies.last ?? ""
	}
}

private actor ReplyRecorder {

	private(set) var requests: [ChatCompletionRequest] = []

	func record(_ request: ChatCompletionRequest) -> Int {
		requests.append(request)
		return requests.count - 1
	}
}

private func configuration(paragraphsPerRequest: Int = 16) -> TranslationConfiguration {
	TranslationConfiguration(
		baseURL: URL(string: "http://127.0.0.1:18000/v1")!,
		model: "Hy-MT2-1.8B-4bit",
		targetLanguage: "Simplified Chinese",
		paragraphsPerRequest: paragraphsPerRequest,
		maxConcurrentRequests: 1
	)
}

final class TranslatorTests: XCTestCase {

	func testSingleParagraphTranslation() async throws {

		let recorder = ReplyRecorder()
		let translator = Translator(
			configuration: configuration(),
			transport: FakeTransport(replies: ["你好"], recorder: recorder)
		)

		let results = try await translator.translate(["Hello"])
		XCTAssertEqual(results, ["你好"])

		let requests = await recorder.requests
		XCTAssertEqual(requests.count, 1)
		XCTAssertEqual(requests[0].model, "Hy-MT2-1.8B-4bit")
		XCTAssertTrue(requests[0].messages[0].content.contains("Simplified Chinese"))
	}

	func testBatchUsesSeparatorAndSplitsReply() async throws {

		let recorder = ReplyRecorder()
		let translator = Translator(
			configuration: configuration(),
			transport: FakeTransport(replies: ["一\n\n%%\n\n二\n\n%%\n\n三"], recorder: recorder)
		)

		let results = try await translator.translate(["one", "two", "three"])
		XCTAssertEqual(results, ["一", "二", "三"])

		let requests = await recorder.requests
		XCTAssertEqual(requests.count, 1)
		XCTAssertTrue(requests[0].messages[1].content.contains("one\n\n%%\n\ntwo"))
	}

	func testDesynchronizedBatchRetriesPerParagraph() async throws {

		let recorder = ReplyRecorder()
		// First reply merges two paragraphs into one; the retries are individual.
		let translator = Translator(
			configuration: configuration(),
			transport: FakeTransport(replies: ["一二", "一", "二"], recorder: recorder)
		)

		let results = try await translator.translate(["one", "two"])
		XCTAssertEqual(results, ["一", "二"])

		let requests = await recorder.requests
		XCTAssertEqual(requests.count, 3)
	}

	func testSeparatorCollisionFallsBackToAnotherSeparator() async throws {

		let recorder = ReplyRecorder()
		let translator = Translator(
			configuration: configuration(),
			transport: FakeTransport(replies: ["甲\n\n[[NNW-PARAGRAPH]]\n\n乙"], recorder: recorder)
		)

		let results = try await translator.translate(["has %% inside", "second"])
		XCTAssertEqual(results, ["甲", "乙"])

		let requests = await recorder.requests
		XCTAssertTrue(requests[0].messages[1].content.contains("[[NNW-PARAGRAPH]]"))
	}

	func testTransportErrorIsSurfaced() async {

		struct FailingTransport: ChatCompletionTransport {
			func complete(_ request: ChatCompletionRequest) async throws -> String {
				throw TranslationError.httpStatus(500, "boom")
			}
		}

		let translator = Translator(configuration: configuration(), transport: FailingTransport())

		do {
			_ = try await translator.translate(["one"])
			XCTFail("Expected a transport error.")
		} catch let error as TranslationError {
			XCTAssertEqual(error, TranslationError.httpStatus(500, "boom"))
		} catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	func testEmptyInputReturnsEmptyOutput() async throws {
		let translator = Translator(configuration: configuration(), transport: FakeTransport(replies: []))
		let results = try await translator.translate([])
		XCTAssertTrue(results.isEmpty)
	}

	func testBatchingSplitsIntoSeparateRequests() async throws {

		let recorder = ReplyRecorder()
		let translator = Translator(
			configuration: configuration(paragraphsPerRequest: 2),
			transport: FakeTransport(replies: ["一\n\n%%\n\n二", "三"], recorder: recorder)
		)

		let results = try await translator.translate(["one", "two", "three"])
		XCTAssertEqual(results, ["一", "二", "三"])

		let requests = await recorder.requests
		XCTAssertEqual(requests.count, 2)
	}

	func testCleanedRemovesThinkBlocksAndCodeFences() {

		XCTAssertEqual(Translator.cleaned("<think>Hmm</think>你好"), "你好")
		XCTAssertEqual(Translator.cleaned("```\n你好\n```"), "你好")
		XCTAssertEqual(Translator.cleaned("  你好  "), "你好")
		XCTAssertEqual(Translator.cleaned("Plain"), "Plain")
	}
}
