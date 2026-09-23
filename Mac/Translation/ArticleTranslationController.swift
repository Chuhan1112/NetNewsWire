//
//  ArticleTranslationController.swift
//  NetNewsWire
//

import Foundation
import Articles
import Translation

/// Runs translations for the detail view and caches the results in memory.
@MainActor final class ArticleTranslationController {

	private let cache = TranslationCache()

	func cachedTranslation(for article: Article) async -> ArticleTranslation? {
		await cache.translation(forKey: TranslationSettings.cacheKey(articleID: article.articleID))
	}

	func translated(_ article: Article, bodyHTML: String) async throws -> ArticleTranslation {

		let key = TranslationSettings.cacheKey(articleID: article.articleID)

		if let cached = await cache.translation(forKey: key) {
			return cached
		}

		let translator = ArticleTranslator(configuration: TranslationSettings.configuration)
		let translation = try await translator.translate(title: article.title, bodyHTML: bodyHTML)
		await cache.store(translation, forKey: key)
		return translation
	}

	/// Sends one short request so the preferences pane can confirm the server answers.
	func testConnection() async throws -> String {
		let translator = Translator(configuration: TranslationSettings.configuration)
		let results = try await translator.translate(["Hello"])
		return results.first ?? ""
	}
}
