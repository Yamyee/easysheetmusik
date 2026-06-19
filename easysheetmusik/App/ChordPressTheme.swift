import UIKit

enum ChordPressTheme {
    enum Color {
        static let primary = UIColor(hex: 0x5645d4)
        static let primaryPressed = UIColor(hex: 0x4534b3)
        static let primaryDeep = UIColor(hex: 0x3a2a99)
        static let onPrimary = UIColor(hex: 0xffffff)

        static let brandNavy = UIColor(hex: 0x0a1530)
        static let brandNavyDeep = UIColor(hex: 0x070f24)
        static let brandNavyMid = UIColor(hex: 0x1a2a52)
        static let linkBlue = UIColor(hex: 0x0075de)
        static let orange = UIColor(hex: 0xdd5b00)
        static let pink = UIColor(hex: 0xff64c8)
        static let purple = UIColor(hex: 0x7b3ff2)
        static let purpleSoft = UIColor(hex: 0xd6b6f6)
        static let purpleDeep = UIColor(hex: 0x391c57)
        static let teal = UIColor(hex: 0x2a9d99)
        static let green = UIColor(hex: 0x1aae39)
        static let yellow = UIColor(hex: 0xf5d75e)

        static let peach = UIColor(hex: 0xffe8d4)
        static let rose = UIColor(hex: 0xfde0ec)
        static let mint = UIColor(hex: 0xd9f3e1)
        static let lavender = UIColor(hex: 0xe6e0f5)
        static let sky = UIColor(hex: 0xdcecfa)
        static let yellowSoft = UIColor(hex: 0xfef7d6)
        static let cream = UIColor(hex: 0xf8f5e8)
        static let gray = UIColor(hex: 0xf0eeec)

        static let canvas = UIColor(hex: 0xffffff)
        static let surface = UIColor(hex: 0xf6f5f4)
        static let surfaceSoft = UIColor(hex: 0xfafaf9)
        static let hairline = UIColor(hex: 0xe5e3df)
        static let hairlineStrong = UIColor(hex: 0xc8c4be)

        static let ink = UIColor(hex: 0x1a1a1a)
        static let charcoal = UIColor(hex: 0x37352f)
        static let slate = UIColor(hex: 0x5d5b54)
        static let steel = UIColor(hex: 0x787671)
        static let stone = UIColor(hex: 0xa4a097)
        static let onDark = UIColor(hex: 0xffffff)
        static let onDarkMuted = UIColor(hex: 0xa4a097)
    }

    enum Radius {
        static let button: CGFloat = 8
        static let card: CGFloat = 12
        static let badge: CGFloat = 8
    }

    static func applyGlobalAppearance(to window: UIWindow) {
        window.tintColor = Color.primary

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = Color.surface
        navigation.shadowColor = Color.hairline
        navigation.titleTextAttributes = [.foregroundColor: Color.charcoal]
        navigation.largeTitleTextAttributes = [.foregroundColor: Color.ink]

        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = Color.primary

        UISearchBar.appearance().tintColor = Color.primary
        UISegmentedControl.appearance().selectedSegmentTintColor = Color.primary
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: Color.onPrimary],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: Color.charcoal],
            for: .normal
        )
    }

    static func primaryButton(title: String, image: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = image.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = image == nil ? 0 : 8
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Color.primary
        configuration.baseForegroundColor = Color.onPrimary
        configuration.background.cornerRadius = Radius.button
        return configuration
    }

    static func secondaryButton(title: String, image: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = image.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = image == nil ? 0 : 8
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Color.lavender
        configuration.baseForegroundColor = Color.primaryDeep
        configuration.background.cornerRadius = Radius.button
        return configuration
    }

    static func secondaryOnDarkButton(title: String, image: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.image = image.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = image == nil ? 0 : 8
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Color.onDark.withAlphaComponent(0.16)
        configuration.baseForegroundColor = Color.onDark
        configuration.background.cornerRadius = Radius.button
        return configuration
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}
