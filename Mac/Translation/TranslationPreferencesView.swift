//
//  TranslationPreferencesView.swift
//  NetNewsWire
//

import SwiftUI

@MainActor final class TranslationPreferencesModel: ObservableObject {

	static let languagePresets = [
		"Simplified Chinese",
		"Traditional Chinese",
		"English",
		"Japanese",
		"Korean",
		"French",
		"German",
		"Spanish",
		"Russian"
	]

	@Published var isEnabled: Bool {
		didSet { AppDefaults.shared.translationEnabled = isEnabled }
	}

	@Published var automatically: Bool {
		didSet { AppDefaults.shared.translationAutomatically = automatically }
	}

	@Published var endpoint: String {
		didSet { AppDefaults.shared.translationEndpoint = endpoint }
	}

	@Published var apiKey: String {
		didSet { AppDefaults.shared.translationAPIKey = apiKey }
	}

	@Published var model: String {
		didSet { AppDefaults.shared.translationModel = model }
	}

	@Published var targetLanguage: String {
		didSet { AppDefaults.shared.translationTargetLanguage = targetLanguage }
	}

	@Published var paragraphsPerRequest: Int {
		didSet { AppDefaults.shared.translationParagraphsPerRequest = paragraphsPerRequest }
	}

	@Published var isTesting = false
	@Published var statusMessage: String?
	@Published var statusIsError = false

	init() {
		self.isEnabled = AppDefaults.shared.translationEnabled
		self.automatically = AppDefaults.shared.translationAutomatically
		self.endpoint = AppDefaults.shared.translationEndpoint
		self.apiKey = AppDefaults.shared.translationAPIKey
		self.model = AppDefaults.shared.translationModel
		self.targetLanguage = AppDefaults.shared.translationTargetLanguage
		self.paragraphsPerRequest = AppDefaults.shared.translationParagraphsPerRequest
	}

	func testConnection() {

		guard !isTesting else {
			return
		}

		isTesting = true
		statusMessage = nil
		statusIsError = false

		let controller = ArticleTranslationController()

		Task { @MainActor in
			defer {
				isTesting = false
			}
			do {
				let reply = try await controller.testConnection()
				statusMessage = NSLocalizedString("Connected. Reply: ", comment: "Translation test") + reply
				statusIsError = false
			} catch {
				statusMessage = error.localizedDescription
				statusIsError = true
			}
		}
	}
}

struct TranslationPreferencesView: View {

	@StateObject private var model = TranslationPreferencesModel()

	static let viewWidth = CGFloat(512)
	static let viewHeight = CGFloat(330)

	var body: some View {

		VStack(alignment: .leading, spacing: 18) {

			Toggle("Enable translation", isOn: $model.isEnabled)

			Toggle("Translate titles and articles automatically", isOn: $model.automatically)
				.disabled(!model.isEnabled)

			VStack(alignment: .leading, spacing: 12) {

				preferenceRow("Endpoint") {
					TextField("http://127.0.0.1:18000/v1", text: $model.endpoint)
						.textFieldStyle(.roundedBorder)
						.frame(maxWidth: 300)
				}

				preferenceRow("API key") {
					SecureField("", text: $model.apiKey)
						.textFieldStyle(.roundedBorder)
						.frame(maxWidth: 300)
				}

				preferenceRow("Model") {
					TextField("Hy-MT2-1.8B-4bit", text: $model.model)
						.textFieldStyle(.roundedBorder)
						.frame(maxWidth: 300)
				}

				preferenceRow("Target language") {
					HStack(spacing: 6) {
						TextField("Simplified Chinese", text: $model.targetLanguage)
							.textFieldStyle(.roundedBorder)
							.frame(maxWidth: 240)
						Menu {
							ForEach(TranslationPreferencesModel.languagePresets, id: \.self) { language in
								Button(language) {
									model.targetLanguage = language
								}
							}
						} label: {
							Image(systemName: "chevron.up.chevron.down")
						}
						.fixedSize()
					}
				}

				preferenceRow("Batching") {
					Stepper(value: $model.paragraphsPerRequest, in: 1...64) {
						Text("\(model.paragraphsPerRequest) paragraphs per request")
					}
				}
			}
			.disabled(!model.isEnabled)

			HStack(spacing: 8) {
				Button("Test connection") {
					model.testConnection()
				}
				.disabled(!model.isEnabled || model.isTesting)

				if model.isTesting {
					ProgressView()
						.controlSize(.small)
				}
			}
			.disabled(!model.isEnabled)

			if let statusMessage = model.statusMessage {
				Text(statusMessage)
					.font(.callout)
					.foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
					.lineLimit(3)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.padding(24)
		.frame(
			width: Self.viewWidth,
			height: Self.viewHeight,
			alignment: .topLeading
		)
	}

	private func preferenceRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
		HStack(spacing: 10) {
			Text(NSLocalizedString(label, comment: "Translation preference"))
				.frame(width: 110, alignment: .trailing)
			content()
			Spacer(minLength: 0)
		}
	}
}
