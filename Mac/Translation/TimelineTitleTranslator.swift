//
//  TimelineTitleTranslator.swift
//  NetNewsWire
//

import Foundation
import Articles
import Translation

/// Translates the titles of the articles currently shown in the timeline.
///
/// Titles are short, so they go out in larger batches than article bodies, and the
/// results stay in memory for the life of the timeline. The cache is invalidated
/// whenever the enable switch, target language, or model changes.
@MainActor final class TimelineTitleTranslator {

	static let shared = TimelineTitleTranslator()

	private struct Fingerprint: Equatable {
		var enabled: Bool
		var automatic: Bool
		var language: String
		var model: String
	}

	private var cache = [String: String]()
	private var inFlight = Set<String>()
	private var fingerprint = TimelineTitleTranslator.currentFingerprint()

	private init() {}

	private static func currentFingerprint() -> Fingerprint {
		Fingerprint(
			enabled: TranslationSettings.isEnabled,
			automatic: TranslationSettings.isAutomatic,
			language: TranslationSettings.targetLanguage,
			model: AppDefaults.shared.translationModel
		)
	}

	func cachedTitle(for article: Article) -> String? {
		syncFingerprint()
		guard TranslationSettings.isEnabled else {
			return nil
		}
		return cache[article.articleID]
	}

	/// Requests translations for the articles whose titles are not cached yet.
	/// `completion` receives the newly translated titles, ready for a row reload.
	func requestTranslations(for articles: [Article], completion: @escaping ([String: String]) -> Void) {

		syncFingerprint()
		guard TranslationSettings.isEnabled, TranslationSettings.isAutomatic else {
			return
		}

		let pending = articles.filter { article in
			guard let title = article.title, !title.isEmpty else {
				return false
			}
			return cache[article.articleID] == nil && !inFlight.contains(article.articleID)
		}

		guard !pending.isEmpty else {
			return
		}

		let titles = Dictionary(uniqueKeysWithValues: pending.map { ($0.articleID, $0.title ?? "") })
		for articleID in titles.keys {
			inFlight.insert(articleID)
		}

		let base = TranslationSettings.configuration
		// Titles are a few tokens each, so they batch much more aggressively than bodies.
		let configuration = TranslationConfiguration(
			baseURL: base.baseURL,
			apiKey: base.apiKey,
			model: base.model,
			targetLanguage: base.targetLanguage,
			paragraphsPerRequest: 32,
			maxConcurrentRequests: 2
		)
		let translator = Translator(configuration: configuration)

		Task { @MainActor in
			defer {
				for articleID in titles.keys {
					inFlight.remove(articleID)
				}
			}
			do {
				let orderedIDs = Array(titles.keys)
				let translated = try await translator.translate(orderedIDs.compactMap { titles[$0] })

				var results = [String: String]()
				for (offset, articleID) in orderedIDs.enumerated() where offset < translated.count {
					let value = translated[offset]
					if !value.isEmpty {
						cache[articleID] = value
						results[articleID] = value
					}
				}
				completion(results)
			} catch {
				// Callers must always get a callback, even on error: anything waiting
				// on the completion would otherwise hang forever. Keep the original
				// titles; the next timeline change retries.
				completion([:])
			}
		}
	}

	/// True when the translation preferences changed since the previous call, so the
	/// timeline can reload its visible rows with original or retranslated titles.
	func fingerprintChanged() -> Bool {
		let current = Self.currentFingerprint()
		let changed = current != fingerprint
		if changed {
			cache.removeAll()
			inFlight.removeAll()
			fingerprint = current
		}
		return changed
	}

	private func syncFingerprint() {
		let current = Self.currentFingerprint()
		if current != fingerprint {
			cache.removeAll()
			inFlight.removeAll()
			fingerprint = current
		}
	}
}
