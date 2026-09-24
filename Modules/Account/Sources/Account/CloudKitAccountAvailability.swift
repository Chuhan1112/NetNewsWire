//
//  CloudKitAccountAvailability.swift
//  Account
//

import Foundation
#if os(macOS)
import Security
#endif

/// Whether this build may use CloudKit at all.
///
/// CloudKit traps inside `CKContainer(identifier:)` when the app has no iCloud
/// entitlements, and a build without a signing identity has none. Both the account UI
/// and the account loader consult this, so a build that cannot use iCloud neither
/// offers an iCloud account nor tries to open one from disk.
public enum CloudKitAccountAvailability {

	public static var isAvailable: Bool {
		hasICloudEntitlement(inBundleAt: Bundle.main.bundleURL)
	}

	/// Takes a bundle path so the check can be exercised against any built app.
	public static func hasICloudEntitlement(inBundleAt bundleURL: URL) -> Bool {
#if os(macOS)
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
#else
		// iOS apps are always signed, so there is nothing to second-guess here.
		return true
#endif
	}
}
