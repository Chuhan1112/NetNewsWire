// swift-tools-version:6.2
import PackageDescription

let package = Package(
	name: "Translation",
	platforms: [.macOS(.v15)],
	products: [
		.library(
			name: "Translation",
			targets: ["Translation"])
	],
	targets: [
		.target(
			name: "Translation",
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
				.enableUpcomingFeature("InferIsolatedConformances")
			]
		),
		.testTarget(
			name: "TranslationTests",
			dependencies: ["Translation"],
			swiftSettings: [.swiftLanguageMode(.v6)]
		)
	]
)
