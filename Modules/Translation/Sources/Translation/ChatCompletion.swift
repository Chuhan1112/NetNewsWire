//
//  ChatCompletion.swift
//  Translation
//

import Foundation

public struct ChatMessage: Sendable, Equatable, Codable {

	public var role: String
	public var content: String

	public init(role: String, content: String) {
		self.role = role
		self.content = content
	}

	public static func system(_ content: String) -> ChatMessage {
		ChatMessage(role: "system", content: content)
	}

	public static func user(_ content: String) -> ChatMessage {
		ChatMessage(role: "user", content: content)
	}
}

public struct ChatCompletionRequest: Sendable, Equatable {

	public var messages: [ChatMessage]
	public var model: String
	public var temperature: Double
	public var maxTokens: Int

	public init(messages: [ChatMessage], model: String, temperature: Double, maxTokens: Int) {
		self.messages = messages
		self.model = model
		self.temperature = temperature
		self.maxTokens = maxTokens
	}
}

/// The single call the translator needs from the outside world. Kept as a protocol so
/// tests can run against a canned transport instead of a live model server.
public protocol ChatCompletionTransport: Sendable {

	/// Returns the assistant's reply text.
	func complete(_ request: ChatCompletionRequest) async throws -> String
}

public enum TranslationError: Error, Sendable, Equatable, LocalizedError {

	case invalidURL(String)
	case httpStatus(Int, String)
	case emptyResponse

	public var errorDescription: String? {
		switch self {
		case .invalidURL(let string):
			return "The translation endpoint is not a valid URL: \(string)"
		case .httpStatus(let code, let body):
			return "The translation service returned HTTP \(code). \(body)"
		case .emptyResponse:
			return "The translation service returned an empty response."
		}
	}
}

/// Talks to an OpenAI-compatible `/chat/completions` endpoint.
public struct URLSessionChatCompletionTransport: ChatCompletionTransport {

	public let endpointURL: URL
	public let apiKey: String
	public let timeout: TimeInterval
	public let session: URLSession

	public init(endpointURL: URL, apiKey: String = "", timeout: TimeInterval = 120, session: URLSession = .shared) {
		self.endpointURL = endpointURL
		self.apiKey = apiKey
		self.timeout = timeout
		self.session = session
	}

	public func complete(_ request: ChatCompletionRequest) async throws -> String {

		var urlRequest = URLRequest(url: endpointURL, timeoutInterval: timeout)
		urlRequest.httpMethod = "POST"
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		if !apiKey.isEmpty {
			urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		}

		let body: [String: Any] = [
			"model": request.model,
			"messages": request.messages.map { ["role": $0.role, "content": $0.content] },
			"temperature": request.temperature,
			"max_tokens": request.maxTokens
		]
		urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

		let (data, response) = try await session.data(for: urlRequest)

		if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
			let snippet = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			throw TranslationError.httpStatus(httpResponse.statusCode, String(snippet.prefix(300)))
		}

		let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
		guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
			throw TranslationError.emptyResponse
		}
		return content
	}
}

private struct ChatCompletionResponse: Decodable {

	struct Choice: Decodable {
		struct Message: Decodable {
			let content: String?
		}
		let message: Message
	}

	let choices: [Choice]
}
