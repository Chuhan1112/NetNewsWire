//
//  TranslationCache.swift
//  Translation
//

import Foundation

/// Bounded in-memory cache so switching away from an article and back does not
/// re-run the model. Keyed by article ID plus target language.
public actor TranslationCache {

	private var entries: [String: ArticleTranslation] = [:]
	private var order: [String] = []
	private let capacity: Int

	public init(capacity: Int = 40) {
		self.capacity = max(1, capacity)
	}

	public func translation(forKey key: String) -> ArticleTranslation? {
		entries[key]
	}

	public func store(_ translation: ArticleTranslation, forKey key: String) {

		if entries[key] == nil {
			order.append(key)
		}
		entries[key] = translation

		while order.count > capacity {
			let oldest = order.removeFirst()
			entries.removeValue(forKey: oldest)
		}
	}

	public func removeAll() {
		entries.removeAll()
		order.removeAll()
	}
}
