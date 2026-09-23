//
//  TranslationPreferencesViewController.swift
//  NetNewsWire
//

import AppKit
import SwiftUI

final class TranslationPreferencesViewController: NSHostingController<TranslationPreferencesView> {

	convenience init() {
		self.init(rootView: TranslationPreferencesView())
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		// The preferences window resizes itself to the view's frame, so give it a fixed size up front.
		view.frame = NSRect(x: 0, y: 0, width: 512, height: 430)
	}
}
