import Foundation

enum ICloudSyncLastActivityFormatting {
    private static let twentyFourHours: TimeInterval = 24 * 60 * 60

    /// Time phrase inserted into `DataPrivacy.iCloudSync.lastActivity.format` as `%@`.
    /// - Parameter localizationLocale: Strings and absolute date formatting use this locale.
    ///   Default is the user’s current locale.
    static func formattedActivityTime(
        lastActivity: Date,
        referenceNow: Date,
        localizationLocale: Locale = .current
    ) -> String {
        let elapsed = referenceNow.timeIntervalSince(lastActivity)
        if elapsed >= twentyFourHours {
            let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(localizationLocale)
            return lastActivity.formatted(style)
        }
        return relativePhrase(since: lastActivity, now: referenceNow, locale: localizationLocale)
    }

    /// Full subtitle line (prefix + time phrase).
    static func lastActivitySubtitle(
        lastActivity: Date,
        referenceNow: Date,
        localizationLocale: Locale = .current
    ) -> String {
        let timePortion = formattedActivityTime(
            lastActivity: lastActivity,
            referenceNow: referenceNow,
            localizationLocale: localizationLocale
        )
        let formatTemplate = String(
            localized: LocalizedStringResource(
                "DataPrivacy.iCloudSync.lastActivity.format",
                locale: localizationLocale,
                bundle: .main
            )
        )
        return String(format: formatTemplate, locale: localizationLocale, timePortion)
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        String(
            localized: LocalizedStringResource(
                String.LocalizationValue(key),
                locale: locale,
                bundle: .main
            )
        )
    }

    private static func relativePhrase(since lastActivity: Date, now: Date, locale: Locale) -> String {
        var totalSeconds = Int(now.timeIntervalSince(lastActivity).rounded(.down))
        if totalSeconds < 1 {
            totalSeconds = 1
        }

        if totalSeconds < 60 {
            if totalSeconds == 1 {
                return localized("DataPrivacy.iCloudSync.lastActivity.relative.seconds.one", locale: locale)
            }
            return String(
                format: localized("DataPrivacy.iCloudSync.lastActivity.relative.seconds.other", locale: locale),
                locale: locale,
                totalSeconds
            )
        }

        let totalMinutes = totalSeconds / 60
        if totalMinutes < 60 {
            if totalMinutes == 1 {
                return localized("DataPrivacy.iCloudSync.lastActivity.relative.minutes.one", locale: locale)
            }
            return String(
                format: localized("DataPrivacy.iCloudSync.lastActivity.relative.minutes.other", locale: locale),
                locale: locale,
                totalMinutes
            )
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if minutes == 0 {
            if hours == 1 {
                return localized("DataPrivacy.iCloudSync.lastActivity.relative.hours.one", locale: locale)
            }
            return String(
                format: localized("DataPrivacy.iCloudSync.lastActivity.relative.hours.other", locale: locale),
                locale: locale,
                hours
            )
        }

        return compoundHoursMinutesPhrase(hours: hours, minutes: minutes, locale: locale)
    }

    private static func compoundHoursMinutesPhrase(hours: Int, minutes: Int, locale: Locale) -> String {
        let hourIsPlural = hours != 1
        let minuteIsPlural = minutes != 1
        if !hourIsPlural && !minuteIsPlural {
            return localized(
                "DataPrivacy.iCloudSync.lastActivity.relative.hoursMinutes.singularSingular",
                locale: locale
            )
        }
        if !hourIsPlural && minuteIsPlural {
            return String(
                format: localized(
                    "DataPrivacy.iCloudSync.lastActivity.relative.hoursMinutes.singularPlural",
                    locale: locale
                ),
                locale: locale,
                minutes
            )
        }
        if hourIsPlural && !minuteIsPlural {
            return String(
                format: localized(
                    "DataPrivacy.iCloudSync.lastActivity.relative.hoursMinutes.pluralSingular",
                    locale: locale
                ),
                locale: locale,
                hours
            )
        }
        return String(
            format: localized(
                "DataPrivacy.iCloudSync.lastActivity.relative.hoursMinutes.pluralPlural",
                locale: locale
            ),
            locale: locale,
            hours,
            minutes
        )
    }
}
