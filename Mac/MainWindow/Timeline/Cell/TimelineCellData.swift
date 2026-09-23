//
//  TimelineCellData.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles
import Images

@MainActor struct TimelineCellData {

	private static let noText = NSLocalizedString("(No Text)", comment: "No Text")

	let title: String
	let attributedTitle: NSAttributedString
	let text: String
	let dateString: String
	let feedName: String
	let byline: String
	let showFeedName: TimelineShowFeedName
	let iconImage: IconImage? // feed icon, user avatar, or favicon
	let showIcon: Bool // Make space even when icon is nil
	let read: Bool
	let starred: Bool

	init(article: Article, showFeedName: TimelineShowFeedName, feedName: String?, byline: String?, iconImage: IconImage?, showIcon: Bool, translatedTitle: String? = nil) {

		// A translated title replaces the original in the timeline; the summary
		// stays in the feed's language, since translating it would cost another
		// request for text the cell may not even show.
		let originalTitle = ArticleStringFormatter.shared.attributedTruncatedTitle(article)
		if let translatedTitle {
			// Swap the characters but keep the original attributed runs: the title
			// field sizer force-unwraps the font attribute at index 0, and the cell
			// merges its base font into existing runs only, so a plain string with
			// no font attribute crashes the layout.
			let translated = NSMutableAttributedString(attributedString: originalTitle)
			translated.replaceCharacters(in: NSRange(location: 0, length: originalTitle.length), with: translatedTitle)
			self.attributedTitle = translated
			self.title = translatedTitle
		} else {
			self.attributedTitle = originalTitle
			self.title = ArticleStringFormatter.shared.truncatedTitle(article)
		}
		self.text = Self.summaryText(for: article, title: self.title)

		self.dateString = ArticleStringFormatter.shared.dateString(article.logicalDatePublished)

		if let feedName = feedName {
			self.feedName = ArticleStringFormatter.shared.truncatedFeedName(feedName)
		} else {
			self.feedName = ""
		}

		if let byline = byline {
			self.byline = byline
		} else {
			self.byline = ""
		}

		self.showFeedName = showFeedName

		self.showIcon = showIcon
		self.iconImage = iconImage

		self.read = article.status.read
		self.starred = article.status.starred
	}

	/// The article’s summary, or “(No Text)” when it has neither a title nor a summary.
	static func summaryText(for article: Article, title: String) -> String {
		let truncatedSummary = ArticleStringFormatter.shared.truncatedSummary(article)
		if title.isEmpty && truncatedSummary.isEmpty {
			return noText
		}
		return truncatedSummary
	}

	init() { // Empty
		self.title = ""
		self.text = ""
		self.dateString = ""
		self.feedName = ""
		self.byline = ""
		self.showFeedName = .none
		self.showIcon = false
		self.iconImage = nil
		self.read = true
		self.starred = false
		self.attributedTitle = NSAttributedString()
	}
}
