import Foundation
import AVFoundation

let voices = AVSpeechSynthesisVoice.speechVoices()
print("==== ALL MAC VOICES ====")
for voice in voices {
    if voice.language.contains("pt") {
        print("PT Voice: \(voice.name) - \(voice.identifier) - Quality: \(voice.quality.rawValue)")
    }
}
print("========================")
