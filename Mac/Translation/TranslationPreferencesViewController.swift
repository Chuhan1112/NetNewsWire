//
//  TranslationPreferencesViewController.swift
//  NetNewsWire
//

import AppKit
import SwiftUI

final class TranslationPreferencesViewController: NSViewController {

	convenience init() {
		self.init(nibName: nil, bundle: nil)
	}

	override func loadView() {
		// The preferences window resizes itself to the view's frame, so the hosting view
		// needs a concrete frame. NSHostingController sizes its view from SwiftUI's ideal
		// size, which a fixed-height layout reports as zero and collapsed the window.
		let hostingView = NSHostingView(rootView: TranslationPreferencesView())
		hostingView.frame = NSRect(
			x: 0,
			y: 0,
			width: TranslationPreferencesView.viewWidth,
			height: TranslationPreferencesView.viewHeight
		)
		view = hostingView
	}
}
