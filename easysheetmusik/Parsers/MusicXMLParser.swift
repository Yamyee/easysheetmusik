import Foundation
import UIKit

final class MusicXMLParser: NSObject, ScoreParserProtocol {
    private var title: String?
    private var artist: String?
    private var tempo = 120.0
    private var divisions = 1.0
    private var events: [PlaybackEvent] = []
    private var measures: [[String]] = []
    private var currentMeasure: [String] = []
    private var currentElement = ""
    private var currentText = ""
    private var currentStep = ""
    private var currentAlter = 0
    private var currentOctave = 4
    private var currentDuration = 1.0
    private var currentIsRest = false
    private var currentIsChord = false
    private var parserError: Error?

    func parse(data: Data, fileName: String?) throws -> MusicScore {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parserError ?? parser.parserError ?? ParserError.invalidFormat
        }
        if !currentMeasure.isEmpty { measures.append(currentMeasure) }
        guard !measures.isEmpty || !events.isEmpty else { throw ParserError.emptyDocument }

        let rendered = makeRenderedScore()
        return MusicScore(
            id: UUID(),
            title: title ?? fileName.map { ($0 as NSString).deletingPathExtension } ?? T("MusicXML 乐谱", "MusicXML Score"),
            artist: artist,
            pages: [ScorePage(number: 1, content: .attributedText(rendered))],
            sourceFormat: .musicXML,
            importedAt: Date(),
            sourceText: String(data: data, encoding: .utf8),
            folder: nil,
            tags: [],
            playbackEvents: events
        )
    }

    private func reset() {
        title = nil
        artist = nil
        tempo = 120
        divisions = 1
        events = []
        measures = []
        currentMeasure = []
        parserError = nil
    }

    private func makeRenderedScore() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let heading = "\(title ?? T("MusicXML 乐谱", "MusicXML Score"))\n\(artist ?? "")\n♩ = \(Int(tempo))\n\n"
        result.append(NSAttributedString(
            string: heading,
            attributes: [.font: UIFont.systemFont(ofSize: 22, weight: .bold)]
        ))

        for (index, measure) in measures.enumerated() {
            result.append(NSAttributedString(
                string: "\(index + 1)  |  \(measure.joined(separator: "  "))  |\n\n",
                attributes: [.font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular)]
            ))
        }
        return result
    }

    private func appendCurrentNote() {
        let beats = max(currentDuration / max(divisions, 1), 0.125)
        let seconds = beats * 60 / tempo

        if currentIsRest {
            currentMeasure.append("𝄽")
            events.append(PlaybackEvent(midiNote: nil, duration: seconds))
        } else if !currentStep.isEmpty {
            let accidental = currentAlter == 1 ? "♯" : currentAlter == -1 ? "♭" : ""
            currentMeasure.append("\(currentStep)\(accidental)\(currentOctave)")
            if !currentIsChord {
                events.append(PlaybackEvent(
                    midiNote: midiNote(step: currentStep, alter: currentAlter, octave: currentOctave),
                    duration: seconds
                ))
            }
        }
    }

    private func midiNote(step: String, alter: Int, octave: Int) -> UInt8? {
        let pitchClasses = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let pitchClass = pitchClasses[step.uppercased()] else { return nil }
        return UInt8(clamping: (octave + 1) * 12 + pitchClass + alter)
    }
}

extension MusicXMLParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        if elementName == "measure" {
            currentMeasure = []
        } else if elementName == "note" {
            currentStep = ""
            currentAlter = 0
            currentOctave = 4
            currentDuration = 1
            currentIsRest = false
            currentIsChord = false
        } else if elementName == "rest" {
            currentIsRest = true
        } else if elementName == "chord" {
            currentIsChord = true
        } else if elementName == "sound", let value = attributeDict["tempo"], let parsed = Double(value) {
            tempo = parsed
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "work-title", "movement-title":
            if title == nil, !value.isEmpty { title = value }
        case "creator":
            if artist == nil, !value.isEmpty { artist = value }
        case "divisions":
            divisions = Double(value) ?? divisions
        case "per-minute":
            tempo = Double(value) ?? tempo
        case "step":
            currentStep = value
        case "alter":
            currentAlter = Int(value) ?? 0
        case "octave":
            currentOctave = Int(value) ?? 4
        case "duration":
            currentDuration = Double(value) ?? 1
        case "note":
            appendCurrentNote()
        case "measure":
            measures.append(currentMeasure)
            currentMeasure = []
        default:
            break
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }
}
