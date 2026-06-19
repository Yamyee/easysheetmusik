import Foundation

struct ChordTransposer {
    private let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let aliases = [
        "DB": "C#", "EB": "D#", "GB": "F#", "AB": "G#", "BB": "A#",
        "CB": "B", "FB": "E", "E#": "F", "B#": "C"
    ]

    func transpose(_ text: String, semitones: Int) -> String {
        guard semitones != 0,
              let regex = try? NSRegularExpression(pattern: #"\[([A-Ga-g])([#b]?)([^\]/]*)(?:/([A-Ga-g])([#b]?))?\]"#)
        else { return text }

        let mutable = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: mutable.length))

        for match in matches.reversed() {
            let root = component(in: text, match: match, noteIndex: 1, accidentalIndex: 2)
            let suffix = substring(in: text, range: match.range(at: 3))
            let bass = component(in: text, match: match, noteIndex: 4, accidentalIndex: 5)
            guard let root, let transposedRoot = transpose(note: root, by: semitones) else { continue }

            var replacement = "[\(transposedRoot)\(suffix)"
            if let bass, let transposedBass = transpose(note: bass, by: semitones) {
                replacement += "/\(transposedBass)"
            }
            replacement += "]"
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        return mutable as String
    }

    private func component(
        in text: String,
        match: NSTextCheckingResult,
        noteIndex: Int,
        accidentalIndex: Int
    ) -> String? {
        guard match.range(at: noteIndex).location != NSNotFound else { return nil }
        return substring(in: text, range: match.range(at: noteIndex))
            + substring(in: text, range: match.range(at: accidentalIndex))
    }

    private func substring(in text: String, range: NSRange) -> String {
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }

    private func transpose(note: String, by semitones: Int) -> String? {
        let normalized = note.uppercased()
        let canonical = aliases[normalized] ?? normalized
        guard let index = notes.firstIndex(of: canonical) else { return nil }
        let nextIndex = (index + semitones % notes.count + notes.count) % notes.count
        return notes[nextIndex]
    }
}
