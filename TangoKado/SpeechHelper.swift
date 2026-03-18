import AVFoundation

final class SpeechHelper: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechHelper()
    private let synthesizer = AVSpeechSynthesizer()

    // Languages where the voice uses Latin script but words are written in non-Latin
    // For these, we extract the romanization from parentheses to speak
    private let latinVoiceLanguages: Set<String> = []

    // Languages with native non-Latin voices that can read their own script
    // For these, we strip the parenthetical romanization
    private let nativeScriptLanguages: Set<String> = ["ru-RU", "ja-JP"]

    override init() {
        super.init()
        synthesizer.delegate = self

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func speak(_ text: String, languageCode: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let speechText: String

        if latinVoiceLanguages.contains(languageCode) {
            // Extract romanization from parentheses: "здраво (zdravo)" -> "zdravo"
            if let match = text.range(of: "\\(([^)]+)\\)", options: .regularExpression),
               let inner = text[match].dropFirst().dropLast() as? Substring {
                speechText = String(inner)
            } else {
                // No parentheses — try speaking as-is
                speechText = text
            }
        } else if nativeScriptLanguages.contains(languageCode) {
            // Strip romanization, keep native script: "привет (privet)" -> "привет"
            speechText = text.replacingOccurrences(
                of: "\\s*\\(.*?\\)",
                with: "",
                options: .regularExpression
            )
        } else {
            // Other languages (Italian, Dutch, German, English) — speak as-is
            speechText = text.replacingOccurrences(
                of: "\\s*\\(.*?\\)",
                with: "",
                options: .regularExpression
            )
        }

        let utterance = AVSpeechUtterance(string: speechText)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
