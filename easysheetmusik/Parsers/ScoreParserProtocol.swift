import Foundation

protocol ScoreParserProtocol {
    func parse(data: Data, fileName: String?) throws -> MusicScore
}

enum ParserError: LocalizedError {
    case invalidFormat
    case emptyDocument
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "无法读取该文件，文件可能已损坏。"
        case .emptyDocument: "乐谱中没有可显示的页面。"
        case .unsupportedFormat: "当前版本尚不支持这种文件格式。"
        }
    }
}
