//
//  AddCloudKitAccount.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import RSCore

enum AddCloudKitAccountError: LocalizedError, RecoverableError, Sendable {
	case iCloudDriveMissing
	case iCloudUnavailableInThisBuild

	var errorDescription: String? {
		switch self {
		case .iCloudDriveMissing, .iCloudUnavailableInThisBuild:
			return NSLocalizedString("Can’t Add iCloud Account", comment: "CloudKit account setup failure description — iCloud Drive not enabled.")
		}
	}

	var recoverySuggestion: String? {
		switch self {
		case .iCloudDriveMissing:
			#if os(macOS)
			return NSLocalizedString("Open System Settings to configure iCloud and enable iCloud Drive.", comment: "CloudKit account setup recovery suggestion")
			#else
			return NSLocalizedString("Open Settings to configure iCloud and enable iCloud Drive.", comment: "CloudKit account setup recovery suggestion")
			#endif
		case .iCloudUnavailableInThisBuild:
			return NSLocalizedString("This build was made without an iCloud signing identity, so iCloud sync is not available in it. A build signed with an iCloud container can sync.", comment: "CloudKit account setup recovery suggestion for unsigned builds")
		}
	}

	var recoveryOptions: [String] {
		switch self {
		case .iCloudDriveMissing:
			#if os(macOS)
			return [NSLocalizedString("Open System Settings", comment: "Open System Settings button"), NSLocalizedString("Cancel", comment: "Cancel button")]
			#else
			return [NSLocalizedString("Open Settings", comment: "Open Settings button"), NSLocalizedString("Cancel", comment: "Cancel button")]
			#endif
		case .iCloudUnavailableInThisBuild:
			return [NSLocalizedString("OK", comment: "OK button")]
		}
	}

	func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool {
		switch self {
		case .iCloudUnavailableInThisBuild:
			return false
		case .iCloudDriveMissing:
			guard recoveryOptionIndex == 0 else {
				return false
			}

			Task { @MainActor in
				AddCloudKitAccountUtilities.openiCloudSettings()
			}

			return true
		}
	}
}

struct AddCloudKitAccountUtilities {
	static var isiCloudDriveEnabled: Bool {
		Platform.deviceHasiCloudAccount
	}

	@MainActor static func openiCloudSettings() {
#if os(macOS)
		if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
			NSWorkspace.shared.open(url)
		}
#else
		if let url = URL(string: "App-prefs:APPLE_ACCOUNT") {
			UIApplication.shared.open(url)
		}
#endif
	}
}
