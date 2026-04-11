import SwiftUI
import UIKit

extension ShareCardStyle {
    func dateFont(for script: ShareTypographyScript) -> Font {
        switch self {
        case .paperWarm:
            switch script {
            case .latin:
                Font.custom("Cormorant Garamond", size: 24, relativeTo: .title2).weight(.semibold)
            case .chinese:
                Font.system(size: 24, weight: .semibold, design: .serif)
            }
        case .editorialMist:
            switch script {
            case .latin:
                Font.custom("Inter", size: 20, relativeTo: .title3).weight(.semibold)
            case .chinese:
                Font.system(size: 20, weight: .semibold, design: .default)
            }
        case .sunriseGradient:
            switch script {
            case .latin:
                Font.custom("Bebas Neue", size: 42, relativeTo: .largeTitle).weight(.regular)
            case .chinese:
                Font.system(size: 28, weight: .semibold, design: .rounded)
            }
        }
    }

    func sectionTitleFont(for script: ShareTypographyScript) -> Font {
        switch self {
        case .paperWarm:
            switch script {
            case .latin:
                Font.custom("Crimson Text", size: 16, relativeTo: .headline).weight(.semibold)
            case .chinese:
                Font.system(size: 16, weight: .semibold, design: .serif)
            }
        case .editorialMist:
            switch script {
            case .latin:
                Font.custom("Inter", size: 13, relativeTo: .subheadline).weight(.semibold)
            case .chinese:
                Font.system(size: 13, weight: .semibold, design: .default)
            }
        case .sunriseGradient:
            switch script {
            case .latin:
                Font.custom("Bebas Neue", size: 22, relativeTo: .title3).weight(.regular)
            case .chinese:
                Font.system(size: 19, weight: .semibold, design: .rounded)
            }
        }
    }

    func bodyFont(for script: ShareTypographyScript) -> Font {
        switch self {
        case .paperWarm:
            switch script {
            case .latin:
                Font.custom("Crimson Text", size: 15, relativeTo: .body)
            case .chinese:
                Font.system(size: 15, weight: .regular, design: .serif)
            }
        case .editorialMist:
            switch script {
            case .latin:
                Font.custom("Spectral-Regular", size: 15, relativeTo: .body)
            case .chinese:
                Font.system(size: 15, weight: .regular, design: .serif)
            }
        case .sunriseGradient:
            switch script {
            case .latin:
                Font.custom("Bodoni Moda", size: 15, relativeTo: .body)
            case .chinese:
                Font.system(size: 16, weight: .medium, design: .rounded)
            }
        }
    }

    func metaFont(for script: ShareTypographyScript) -> Font {
        switch self {
        case .paperWarm:
            switch script {
            case .latin:
                Font.custom("Crimson Text", size: 11, relativeTo: .caption2)
            case .chinese:
                Font.system(size: 11, weight: .regular, design: .serif)
            }
        case .editorialMist:
            switch script {
            case .latin:
                Font.custom("Inter", size: 10, relativeTo: .caption2)
            case .chinese:
                Font.system(size: 10, weight: .regular, design: .default)
            }
        case .sunriseGradient:
            switch script {
            case .latin:
                Font.custom("Bodoni Moda", size: 9, relativeTo: .caption2)
            case .chinese:
                Font.system(size: 10, weight: .regular, design: .rounded)
            }
        }
    }

    func sectionTitleTextCase(for script: ShareTypographyScript) -> Text.Case? {
        switch script {
        case .chinese:
            return nil
        case .latin:
            return .uppercase
        }
    }

    func dateTracking(for script: ShareTypographyScript) -> CGFloat? {
        guard self == .sunriseGradient, script == .latin else { return nil }
        return UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 3.2)
    }
}
