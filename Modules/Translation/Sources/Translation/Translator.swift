//
//  Translator.swift
//  Translation
//

import Foundation

/// Translates plain paragraphs through an OpenAI-compatible endpoint.
///
/// Batches paragraphs into one request using a separator, and verifies that the
/// reply has exactly as many parts as the input. A desynchronized reply is retried
/// one paragraph at a time so a single stray separator can never shift the rest of
/// the article.
public struct Translator: Sendable {

	public let configuration: TranslationConfiguration
	private let transport: any ChatCompletionTransport

	private static let separatorCandidates = ["%%", "[[NNW-PARAGRAPH]]", "<<NNW-BREAK>>", "NNW-PARAGRAPH-SPLIT"]

	public init(configuration: TranslationConfiguration, transport: any ChatCompletionTransport) {
		self.configuration = configuration
		self.transport = transport
	}

	public init(configuration: TranslationConfiguration) {
		self.init(
			configuration: configuration,
			transport: URLSessionChatCompletionTransport(
				endpointURL: configuration.chatCompletionsURL,
				apiKey: configuration.apiKey,
				timeout: configuration.timeout
			)
		)
	}

	/// Returns one translated string per input paragraph, in the same order.
	/// Never returns fewer or more than `paragraphs.count`.
	public func translate(_ paragraphs: [String]) async throws -> [String] {

		guard !paragraphs.isEmpty else {
			return []
		}

		let separator = Self.separator(for: paragraphs, preferred: configuration.batchSeparator)
		let batchSize = configuration.paragraphsPerRequest
		let windowSize = batchSize * configuration.maxConcurrentRequests

		var results = [String](repeating: "", count: paragraphs.count)
		let transport = self.transport
		let configuration = self.configuration

		var windowStart = 0
		while windowStart < paragraphs.count {

			let windowEnd = min(windowStart + windowSize, paragraphs.count)

			try await withThrowingTaskGroup(of: (Int, [String]).self) { group in

				for batchStart in stride(from: windowStart, to: windowEnd, by: batchSize) {
					let batchEnd = min(batchStart + batchSize, windowEnd)
					let batch = Array(paragraphs[batchStart..<batchEnd])
					let batchStart = batchStart

					group.addTask {
						let translated = try await Self.translateBatch(
							batch,
							separator: separator,
							configuration: configuration,
							transport: transport
						)
						return (batchStart, translated)
					}
				}

				for try await (batchStart, translated) in group {
					for (offset, value) in translated.enumerated() {
						results[batchStart + offset] = value
					}
				}
			}

			windowStart = windowEnd
		}

		return results
	}

	// MARK: - Private

	private static func translateBatch(
		_ batch: [String],
		separator: String,
		configuration: TranslationConfiguration,
		transport: any ChatCompletionTransport
	) async throws -> [String] {

		let reply = try await request(batch, separator: separator, configuration: configuration, transport: transport)

		// A single-paragraph batch has no separator by contract.
		if batch.count == 1 {
			return [Self.cleaned(reply)]
		}

		let parts = Self.split(reply, separator: separator)
		if parts.count == batch.count {
			return parts
		}

		return await individually(batch, configuration: configuration, transport: transport)
	}

	/// Recovers from a desynchronized batch by asking for one paragraph at a time.
	private static func individually(
		_ batch: [String],
		configuration: TranslationConfiguration,
		transport: any ChatCompletionTransport
	) async -> [String] {

		var output = batch

		for (index, paragraph) in batch.enumerated() {
			guard let reply = try? await request([paragraph], separator: configuration.batchSeparator, configuration: configuration, transport: transport) else {
				continue
			}
			let text = Self.cleaned(reply)
			if !text.isEmpty {
				output[index] = text
			}
		}

		return output
	}

	private static func request(
		_ paragraphs: [String],
		separator: String,
		configuration: TranslationConfiguration,
		transport: any ChatCompletionTransport
	) async throws -> String {

		let target = configuration.targetLanguage
		let system = configuration.systemPromptTemplate.replacingOccurrences(of: "{{to}}", with: target)

		let joined = paragraphs.joined(separator: "\n\n\(separator)\n\n")
		let user = configuration.userPromptTemplate
			.replacingOccurrences(of: "{{to}}", with: target)
			.replacingOccurrences(of: "{{text}}", with: joined)

		let request = ChatCompletionRequest(
			messages: [.system(system), .user(user)],
			model: configuration.model,
			temperature: configuration.temperature,
			maxTokens: configuration.maxTokens
		)

		return try await transport.complete(request)
	}

	private static func split(_ reply: String, separator: String) -> [String] {
		cleaned(reply)
			.components(separatedBy: separator)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	/// Trims reasoning blocks, code fences, and stray whitespace from a raw reply.
	static func cleaned(_ reply: String) -> String {

		var text = removingThinkBlocks(reply).trimmingCharacters(in: .whitespacesAndNewlines)

		if text.hasPrefix("```") {
			let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
			if lines.count >= 2, lines.last?.trimmingCharacters(in: .whitespaces) == "```" {
				text = lines[1..<(lines.count - 1)].joined(separator: "\n")
					.trimmingCharacters(in: .whitespacesAndNewlines)
			}
		}

		return text
	}

	/// Some servers inline `<think>…</think>` reasoning in the message content.
	static func removingThinkBlocks(_ text: String) -> String {

		var out = text

		while let start = out.range(of: "<think", options: .caseInsensitive) {
			guard let openEnd = out[start.upperBound...].range(of: ">") else {
				return String(out[..<start.lowerBound])
			}
			guard let end = out[openEnd.upperBound...].range(of: "</", options: .caseInsensitive) else {
				return String(out[..<start.lowerBound])
			}
			guard let endTagEnd = out[end.upperBound...].firstIndex(of: ">") else {
				return String(out[..<start.lowerBound])
			}
			out = String(out[..<start.lowerBound]) + String(out[out.index(after: endTagEnd)...])
		}

		return out
	}

	/// Picks a separator that does not already appear in the source text.
	private static func separator(for paragraphs: [String], preferred: String) -> String {

		let candidates = [preferred] + Self.separatorCandidates

		for candidate in candidates {
			if !paragraphs.contains(where: { $0.contains(candidate) }) {
				return candidate
			}
		}

		return candidates.last!
	}
}
