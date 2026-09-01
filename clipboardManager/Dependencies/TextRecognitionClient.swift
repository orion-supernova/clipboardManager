//
//  TextRecognitionClient.swift
//  clipboardManager
//
//  On-device OCR (Vision) so screenshots and copied images can be searched.
//

import ComposableArchitecture
import Foundation
import Vision

struct TextRecognitionClient: Sendable {
    var recognize: @Sendable (URL) async -> String?
}

extension TextRecognitionClient: DependencyKey {
    static let liveValue = TextRecognitionClient { url in
        await Task.detached(priority: .utility) {
            guard let image = ImageCoding.thumbnail(fromFileAt: url, maxPixelSize: 2048) else { return nil }
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            guard let observations = try? await request.perform(on: image) else { return nil }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.count >= 3 ? text : nil
        }.value
    }

    static let previewValue = TextRecognitionClient { _ in nil }
}

extension DependencyValues {
    var textRecognition: TextRecognitionClient {
        get { self[TextRecognitionClient.self] }
        set { self[TextRecognitionClient.self] = newValue }
    }
}
