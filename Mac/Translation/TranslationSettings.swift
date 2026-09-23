//
//  TranslationSettings.swift
//  NetNewsWire
//

import Foundation
import Translation

/// Reads the user's translation preferences out of `AppDefaults` and turns them into
/// a `TranslationConfiguration`.
@MainActor enum TranslationSettings {

	static var isEnabled: Bool {
		AppDefaults.shared.translationEnabled
	}

	/// True when titles and the open article translate as they appear; false means
	/// translation happens only through the toolbar's Translate button.
	static var isAutomatic: Bool {
		AppDefaults.shared.translationAutomatically
	}

	static var targetLanguage: String {
		AppDefaults.shared.translationTargetLanguage
	}

	static var baseURL: URL {
		let raw = AppDefaults.shared.translationEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = URL(string: raw), url.scheme != nil else {
			return URL(string: "http://127.0.0.1:18000/v1")!
		}
		return url
	}

	static var configuration: TranslationConfiguration {
		TranslationConfiguration(
			baseURL: baseURL,
			apiKey: AppDefaults.shared.translationAPIKey,
			model: AppDefaults.shared.translationModel,
			targetLanguage: AppDefaults.shared.translationTargetLanguage,
			paragraphsPerRequest: AppDefaults.shared.translationParagraphsPerRequest
		)
	}

	/// Translations are cached per article, target language, and model so that changing
	/// any of them invalidates what is stored.
	static func cacheKey(articleID: String) -> String {
		let language = AppDefaults.shared.translationTargetLanguage
		let model = AppDefaults.shared.translationModel
		return "\(articleID)|\(language)|\(model)"
	}
}
