//
//  DetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit
import RSCore
import Articles
import RSWeb
import Translation

enum DetailState: Equatable {
	case noSelection
	case multipleSelection
	case loading
	case article(Article, CGFloat?)
	case extracted(Article, ExtractedArticle, CGFloat?)
}

final class DetailViewController: NSViewController, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!
	@IBOutlet var statusBarView: DetailStatusBarView!

	private lazy var regularWebViewController = createWebViewController()
	private var searchWebViewController: DetailWebViewController?

	var windowState: DetailWindowState {
		currentWebViewController.windowState
	}

	private var currentWebViewController: DetailWebViewController! {
		didSet {
			let webview = currentWebViewController.view
			if containerView.contentView === webview {
				return
			}
			statusBarView.mouseoverLink = nil
			containerView.contentView = webview
		}
	}

	private var currentSourceMode: TimelineSourceMode = .regular {
		didSet {
			currentWebViewController = webViewController(for: currentSourceMode)
		}
	}

	private var detailStateForRegular: DetailState = .noSelection {
		didSet {
			webViewController(for: .regular).state = detailStateForRegular
		}
	}

	private var detailStateForSearch: DetailState = .noSelection {
		didSet {
			webViewController(for: .search).state = detailStateForSearch
		}
	}

	private let translationController = ArticleTranslationController()
	private var translatedArticle: ArticleTranslation?
	private var translatedArticleID: String?
	private var isTranslatingArticle = false

	convenience init() {
		self.init(nibName: "DetailView", bundle: nil)
	}

	override func viewDidLoad() {
		currentWebViewController = regularWebViewController
	}

	// MARK: - API

	func setState(_ state: DetailState, mode: TimelineSourceMode) {
		switch mode {
		case .regular:
			detailStateForRegular = state
		case .search:
			detailStateForSearch = state
		}

		// A translation belongs to one article; drop it when the selection moves.
		if articleID(for: state) != translatedArticleID {
			translatedArticle = nil
			translatedArticleID = nil
			webViewController(for: mode).translatedArticle = nil
			if !isTranslatingArticle {
				statusBarView.statusText = nil
			}
		}
	}

	func showDetail(for mode: TimelineSourceMode) {
		currentSourceMode = mode
	}

	func stopMediaPlayback() {
		currentWebViewController.stopMediaPlayback()
	}

	func fetchSelectedHTML(_ completion: @escaping (String?) -> Void) {
		currentWebViewController.fetchSelectedHTML(completion)
	}

	func canScrollDown() async -> Bool {
		await currentWebViewController.canScrollDown()
	}

	func canScrollUp() async -> Bool {
		await currentWebViewController.canScrollUp()
	}

	override func scrollPageDown(_ sender: Any?) {
		currentWebViewController.scrollPageDown(sender)
	}

	override func scrollPageUp(_ sender: Any?) {
		currentWebViewController.scrollPageUp(sender)
	}

	// MARK: - Navigation

	func focus() {
		guard let window = currentWebViewController.webView.window else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(currentWebViewController.webView)
	}
	// MARK: - Translation

	var canTranslateArticle: Bool {
		guard TranslationSettings.isEnabled else {
			return false
		}
		return displayedArticle != nil
	}

	var isShowingTranslatedArticle: Bool {
		translatedArticleID != nil
	}

	@objc func toggleArticleTranslation(_ sender: Any?) {

		guard TranslationSettings.isEnabled, let article = displayedArticle else {
			return
		}

		if translatedArticleID == article.articleID {
			clearTranslation()
			return
		}

		guard !isTranslatingArticle else {
			return
		}

		let bodyHTML = displayedBodyHTML
		guard !bodyHTML.isEmpty else {
			return
		}

		isTranslatingArticle = true
		statusBarView.statusText = NSLocalizedString("Translating…", comment: "Translating status")

		let controller = translationController
		let mode = currentSourceMode

		Task { @MainActor in
			do {
				let translation = try await controller.translated(article, bodyHTML: bodyHTML)
				translatedArticle = translation
				translatedArticleID = article.articleID
				webViewController(for: mode).translatedArticle = translation
				statusBarView.statusText = nil
			} catch {
				statusBarView.statusText = nil
				presentTranslationError(error)
			}
			isTranslatingArticle = false
		}
	}
}

// MARK: - DetailWebViewControllerDelegate

extension DetailViewController: DetailWebViewControllerDelegate {

	func mouseDidEnter(_ detailWebViewController: DetailWebViewController, link: String) {
		guard !link.isEmpty, detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = link
	}

	func mouseDidExit(_ detailWebViewController: DetailWebViewController) {
		guard detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = nil
	}
}

// MARK: - Private

private extension DetailViewController {

	func createWebViewController() -> DetailWebViewController {
		let controller = DetailWebViewController()
		controller.delegate = self
		controller.state = .noSelection
		return controller
	}

	func webViewController(for mode: TimelineSourceMode) -> DetailWebViewController {
		switch mode {
		case .regular:
			return regularWebViewController
		case .search:
			if searchWebViewController == nil {
				searchWebViewController = createWebViewController()
			}
			return searchWebViewController!
		}
	}

	private var currentDetailState: DetailState {
		switch currentSourceMode {
		case .regular:
			return detailStateForRegular
		case .search:
			return detailStateForSearch
		}
	}

	private var displayedArticle: Article? {
		switch currentDetailState {
		case .article(let article, _):
			return article
		case .extracted(let article, _, _):
			return article
		case .noSelection, .multipleSelection, .loading:
			return nil
		}
	}

	/// The same body HTML the renderer uses, so the model sees what the reader sees.
	private var displayedBodyHTML: String {
		switch currentDetailState {
		case .article(let article, _):
			return ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(article.body ?? "")
		case .extracted(_, let extractedArticle, _):
			return ArticleRenderingSpecialCases.extractBodyFragmentIfNeeded(extractedArticle.content ?? "")
		case .noSelection, .multipleSelection, .loading:
			return ""
		}
	}

	private func articleID(for state: DetailState) -> String? {
		switch state {
		case .article(let article, _):
			return article.articleID
		case .extracted(let article, _, _):
			return article.articleID
		case .noSelection, .multipleSelection, .loading:
			return nil
		}
	}

	private func clearTranslation() {
		translatedArticle = nil
		translatedArticleID = nil
		webViewController(for: currentSourceMode).translatedArticle = nil
		statusBarView.statusText = nil
	}

	private func presentTranslationError(_ error: Error) {

		guard let window = view.window else {
			return
		}

		let alert = NSAlert()
		alert.messageText = NSLocalizedString("Translation Failed", comment: "Translation Failed")
		alert.informativeText = error.localizedDescription
		alert.alertStyle = .warning
		alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK"))
		alert.beginSheetModal(for: window)
	}
}
