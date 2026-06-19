import Foundation

enum AppLocalization {
    static var usesChinese: Bool {
        if let regionID = Locale.current.region?.identifier.uppercased(),
           regionID == "CN" || regionID == "CHN" {
            return true
        }
        return Locale.current.identifier.uppercased().contains("_CN")
    }

    static func text(_ chinese: String, _ english: String) -> String {
        usesChinese ? chinese : english
    }
}

func T(_ chinese: String, _ english: String) -> String {
    AppLocalization.text(chinese, english)
}
