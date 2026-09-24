//
//  CloudKitAccountAvailability.swift
//  NetNewsWire
//

import Foundation
import Security

/// Whether this build may use CloudKit at all.
///
/// CloudKit traps inside `CKContainer(identifier:)` when the app has no iCloud
/// entitlements, and a build without a signing identity has none — an unsigned build
/// of this fork, for instance. Offering iCloud there means adding an account crashes
/// the app, so the account sheet has to ask first.
enum CloudKitAccountAvailability {

	static var isAvailable: Bool {
		hasICloudEntitlement(inBundleAt: Bundle.main.bundleURL)
	}

	/// Takes a bundle path so the check can be exercised against any built app.
	static func hasICloudEntitlement(inBundleAt bundleURL: URL) -> Bool {

		var code: SecStaticCode?
		guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &code) == errSecSuccess, let code else {
			return false
		}

		var information: CFDictionary?
		let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
		guard SecCodeCopySigningInformation(code, flags, &information) == errSecSuccess,
			  let signingInformation = information as? [String: Any] else {
			return false
		}

		let entitlements = (signingInformation["entitlements-dict"] as? [String: Any])
			?? (signingInformation["entitlements"] as? [String: Any])
		return entitlements?["com.apple.developer.icloud-container-identifiers"] != nil
	}
}
