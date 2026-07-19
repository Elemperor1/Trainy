import Foundation

extension String {
    /// Formats a HH:MM time string according to an explicit interface preference.
    func formattedAsTime(
        in timeZone: TimeZone,
        format: UserPreferences.TimeFormat
    ) -> String {
        let pieces = split(separator: ":").compactMap { Int($0) }
        guard pieces.count >= 2 else { return self }

        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)

        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = components.day
        dateComponents.hour = pieces[0]
        dateComponents.minute = pieces[1]

        guard let date = calendar.date(from: dateComponents) else {
            return self
        }
        return format.makeFormatter(timeZone: timeZone).string(from: date)
    }
}
