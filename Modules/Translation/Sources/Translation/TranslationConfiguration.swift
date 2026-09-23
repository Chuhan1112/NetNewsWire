//
//  TranslationConfiguration.swift
//  Translation
//

import Foundation

/// Everything needed to talk to one OpenAI-compatible chat completions endpoint.
///
/// The defaults match a local oMLX / MLX server, which is how NetNewsWire talks to
/// on-device models such as `Hy-MT2-1.8B-4bit`. Any server speaking the same wire
/// format works, including remote ones, since the endpoint is user-configurable.
public struct TranslationConfiguration: Sendable, Equatable {

	/// Base URL of the API, for example `http://127.0.0.1:18000/v1`.
	/// A URL that already points at `chat/completions` is used as-is.
	public var baseURL: URL

	public var apiKey: String
	public var model: String
	public var targetLanguage: String

	/// How many paragraphs to send in a single request. Larger batches are faster
	/// but a desynchronized reply costs more to recover from.
	public var paragraphsPerRequest: Int

	/// How many requests may be in flight at once.
	public var maxConcurrentRequests: Int

	public var temperature: Double
	public var maxTokens: Int
	public var timeout: TimeInterval

	/// `{{to}}` is replaced with the target language.
	public var systemPromptTemplate: String

	/// `{{to}}` is replaced with the target language, `{{text}}` with the batch.
	public var userPromptTemplate: String

	/// Separator placed between paragraphs of one batch request.
	public var batchSeparator: String

	public init(
		baseURL: URL,
		apiKey: String = "",
		model: String,
		targetLanguage: String = "Simplified Chinese",
		paragraphsPerRequest: Int = 8,
		maxConcurrentRequests: Int = 4,
		temperature: Double = 0,
		maxTokens: Int = 8192,
		timeout: TimeInterval = 120,
		systemPromptTemplate: String = TranslationConfiguration.defaultSystemPromptTemplate,
		userPromptTemplate: String = TranslationConfiguration.defaultUserPromptTemplate,
		batchSeparator: String = TranslationConfiguration.defaultBatchSeparator
	) {
		self.baseURL = baseURL
		self.apiKey = apiKey
		self.model = model
		self.targetLanguage = targetLanguage
		self.paragraphsPerRequest = max(1, paragraphsPerRequest)
		self.maxConcurrentRequests = max(1, maxConcurrentRequests)
		self.temperature = temperature
		self.maxTokens = maxTokens
		self.timeout = timeout
		self.systemPromptTemplate = systemPromptTemplate
		self.userPromptTemplate = userPromptTemplate
		self.batchSeparator = batchSeparator
	}

	/// A ready-made configuration for a local oMLX server.
	public static func oMLX(
		baseURL: URL = URL(string: "http://127.0.0.1:18000/v1")!,
		apiKey: String = "",
		model: String = "Hy-MT2-1.8B-4bit",
		targetLanguage: String = "Simplified Chinese"
	) -> TranslationConfiguration {
		TranslationConfiguration(baseURL: baseURL, apiKey: apiKey, model: model, targetLanguage: targetLanguage)
	}

	public static let defaultBatchSeparator = "%%"

	public static let defaultUserPromptTemplate = "Translate to {{to}}:\n\n{{text}}"

	public static let defaultSystemPromptTemplate = """
You are a professional {{to}} native translator who needs to fluently translate text into {{to}}.

## Translation Rules

1. Output only the translated content, without explanations or additional content (such as "Here's the translation:" or "Translation as follows:")
2. The returned translation must maintain exactly the same number of paragraphs and format as the original text
3. If the text contains HTML tags, consider where the tags should be placed in the translation while maintaining fluency
4. For content that should not be translated (such as proper nouns, code, etc.), keep the original text.
5. If input contains %%, use %% in your output, if input has no %%, don't use %% in your output
6. Preserve all numbers, units, and symbols exactly as they appear in the source text
7. Keep terminology consistent throughout the entire document

## OUTPUT FORMAT:

- **Single paragraph input** → Output translation directly (no separators, no extra text)
- **Multi-paragraph input** → Use %% as paragraph separator between translations

## Examples

### Multi-paragraph Input:

Paragraph A

%%

Paragraph B

%%

Paragraph C

### Multi-paragraph Output:

Translation A

%%

Translation B

%%

Translation C

### Single paragraph Input:

Single paragraph content

### Single paragraph Output:

Direct translation without separators

## Notes

- Do not add, remove, or reorder any content
- Do not translate code blocks, file paths, or command names
"""

	/// The URL requests are actually sent to, derived from `baseURL`.
	public var chatCompletionsURL: URL {
		if baseURL.path.hasSuffix("/chat/completions") {
			return baseURL
		}
		return baseURL.appendingPathComponent("chat/completions")
	}
}
