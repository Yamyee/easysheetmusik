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
        case .invalidFormat: T("无法读取该文件，文件可能已损坏。", "This file could not be read. It may be damaged.")
        case .emptyDocument: T("乐谱中没有可显示的页面。", "This score has no displayable pages.")
        case .unsupportedFormat: T("当前版本尚不支持这种文件格式。", "This file format is not supported in the current version.")
        }
    }
}
