//
//  TranslationPreferencesView.swift
//  NetNewsWire
//

import SwiftUI
import Translation

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

	private let width = CGFloat(512)

	var body: some View {

		Form {
			Section {
				Toggle(isOn: $model.isEnabled) {
					Text("Enable translation")
				}
			}

			Section {
				LabeledContent {
					TextField("http://127.0.0.1:18000/v1", text: $model.endpoint)
						.textFieldStyle(.roundedBorder)
				} label: {
					Text("Endpoint")
				}

				LabeledContent {
					SecureField("", text: $model.apiKey)
						.textFieldStyle(.roundedBorder)
				} label: {
					Text("API key")
				}

				LabeledContent {
					TextField("Hy-MT2-1.8B-4bit", text: $model.model)
						.textFieldStyle(.roundedBorder)
				} label: {
					Text("Model")
				}

				LabeledContent {
					HStack(spacing: 6) {
						TextField("Simplified Chinese", text: $model.targetLanguage)
							.textFieldStyle(.roundedBorder)
						Menu {
							ForEach(TranslationPreferencesModel.languagePresets, id: \.self) { language in
								Button(language) {
									model.targetLanguage = language
								}
							}
						} label: {
							Image(systemName: "chevron.down.circle")
						}
						.menuStyle(.borderlessButton)
						.frame(width: 22)
					}
				} label: {
					Text("Target language")
				}

				LabeledContent {
					Stepper(value: $model.paragraphsPerRequest, in: 1...64) {
						Text("\(model.paragraphsPerRequest) paragraphs per request")
					}
				} label: {
					Text("Batching")
				}
			}
			.disabled(!model.isEnabled)

			Section {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Button {
						model.testConnection()
					} label: {
						Text("Test connection")
					}
					.disabled(!model.isEnabled || model.isTesting)

					if model.isTesting {
						ProgressView()
							.controlSize(.small)
					}
				}

				if let statusMessage = model.statusMessage {
					Text(statusMessage)
						.font(.callout)
						.foregroundStyle(model.statusIsError ? Color.red : Color.secondary)
						.lineLimit(3)
				}
			}
			.disabled(!model.isEnabled)
		}
		.formStyle(.grouped)
		.frame(width: width, height: 430)
	}
}
