import SwiftUI

/// Searchable IANA zones avoid a long menu of ambiguous abbreviations or fixed offsets.
struct TimeZonePicker: View {
    let model: MarketSessionsModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time zone")
                .font(.headline)

            TextField("Search by city or region", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search time zones")

            List(selection: selection) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System (automatic)")
                    Text(displayName(model.systemTimeZone.identifier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag("")

                Section("Time zones") {
                    ForEach(filteredIdentifiers, id: \.self) { identifier in
                        HStack {
                            Text(displayName(identifier))
                            Spacer()
                            Text(TimeZone(identifier: identifier)?.abbreviation(for: model.now) ?? "")
                                .foregroundStyle(.secondary)
                        }
                        .tag(identifier)
                    }
                }
            }
            .listStyle(.inset)

            HStack {
                Text("Changes save automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 460)
    }

    private var selection: Binding<String?> {
        Binding(
            get: { model.preferences.timeZoneIdentifier ?? "" },
            set: { identifier in
                guard let identifier else { return }
                model.setDisplayTimeZone(identifier.isEmpty ? nil : identifier)
            }
        )
    }

    private var filteredIdentifiers: [String] {
        var identifiers = Set(TimeZone.knownTimeZoneIdentifiers)
        identifiers.insert("UTC")
        identifiers.insert(model.systemTimeZone.identifier)
        if let selected = model.preferences.timeZoneIdentifier {
            identifiers.insert(selected)
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return identifiers.sorted().filter {
            query.isEmpty || displayName($0).localizedCaseInsensitiveContains(query)
        }
    }

    private func displayName(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }
}
