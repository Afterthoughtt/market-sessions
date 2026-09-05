import SwiftUI

/// Pop-up chooser limited to North American zones plus UTC (the Daily Close reference).
/// Backed by IANA identifiers so DST rules stay correct; labels are the familiar zone names.
struct TimeZonePicker: View {
    let model: MarketSessionsModel

    /// West to east. Places with their own DST rules (Vancouver, Arizona, Mexico City)
    /// get their own entries so the tz database, not the label, decides their offset.
    static let zones: [(identifier: String, name: String)] = [
        ("Pacific/Honolulu", "Hawaii Time"),
        ("America/Anchorage", "Alaska Time"),
        ("America/Los_Angeles", "Pacific Time"),
        ("America/Vancouver", "Vancouver"),
        ("America/Phoenix", "Arizona"),
        ("America/Denver", "Mountain Time"),
        ("America/Chicago", "Central Time"),
        ("America/Mexico_City", "Mexico City"),
        ("America/New_York", "Eastern Time"),
        ("America/Halifax", "Atlantic Time"),
        ("America/St_Johns", "Newfoundland Time"),
        ("UTC", "UTC"),
    ]

    var body: some View {
        Picker("Time Zone", selection: selection) {
            Text("System").tag("")
            Divider()
            ForEach(options, id: \.identifier) { zone in
                Text(zone.name).tag(zone.identifier)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// Row subtitle for the active display zone: "Pacific Daylight Time (UTC−7)",
    /// evaluated against the model clock so it follows daylight-saving changes.
    static func detail(for timeZone: TimeZone, at now: Date) -> String {
        let style: TimeZone.NameStyle = timeZone.isDaylightSavingTime(for: now) ? .daylightSaving : .standard
        let name = timeZone.localizedName(for: style, locale: .current) ?? timeZone.identifier
        let seconds = timeZone.secondsFromGMT(for: now)
        guard seconds != 0 else { return name }
        let hours = abs(seconds) / 3600
        let minutes = abs(seconds) % 3600 / 60
        let sign = seconds < 0 ? "−" : "+"
        let offset = minutes == 0 ? "UTC\(sign)\(hours)" : "UTC\(sign)\(hours):\(String(format: "%02d", minutes))"
        return "\(name) (\(offset))"
    }

    /// The bundled list, plus any previously stored identifier outside it so the
    /// pop-up can still show the current choice.
    private var options: [(identifier: String, name: String)] {
        guard let stored = model.preferences.timeZoneIdentifier,
              !Self.zones.contains(where: { $0.identifier == stored })
        else { return Self.zones }
        return Self.zones + [(stored, stored.replacingOccurrences(of: "_", with: " "))]
    }

    private var selection: Binding<String> {
        Binding(
            get: { model.preferences.timeZoneIdentifier ?? "" },
            set: { model.setDisplayTimeZone($0.isEmpty ? nil : $0) }
        )
    }
}
