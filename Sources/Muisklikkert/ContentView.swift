import SwiftUI
import Charts
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject private var store: ClickStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let today = store.today

        VStack(alignment: .leading, spacing: 14) {
            // Vandaag
            VStack(alignment: .leading, spacing: 2) {
                Text("Vandaag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(today.total.formatted())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                HStack(spacing: 14) {
                    stat("Links", today.left)
                    stat("Rechts", today.right)
                    stat("Overig", today.other)
                }
            }

            HStack {
                Text("Laatste 24 uur")
                Spacer()
                Text(store.last24Hours.formatted()).monospacedDigit()
            }
            .font(.callout)

            // Per uur
            VStack(alignment: .leading, spacing: 6) {
                Text("Per uur")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart(Array(today.hours.enumerated()), id: \.offset) { hour, count in
                    BarMark(x: .value("Uur", hour), y: .value("Klikken", count))
                        .foregroundStyle(Color.accentColor.gradient)
                }
                .chartXScale(domain: -0.5...23.5)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)u") }
                    }
                }
                .frame(height: 90)
            }

            Divider()

            // Geschiedenis
            VStack(alignment: .leading, spacing: 6) {
                Text("Afgelopen 7 dagen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let recent = store.recentDays(7)
                let maxTotal = max(recent.map(\.stats.total).max() ?? 0, 1)
                ForEach(recent, id: \.date) { day in
                    HStack(spacing: 8) {
                        Text(dayLabel(day.date))
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: max(2, geo.size.width * CGFloat(day.stats.total) / CGFloat(maxTotal)))
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 6)
                        Text(day.stats.total.formatted())
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                    .font(.callout)
                }
                if let record = store.recordDay, record.total > 0 {
                    Text("Record: \(record.total.formatted()) klikken op \(recordLabel(record.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("Start bij inloggen", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }

            HStack {
                Button("Open gegevensmap") {
                    store.saveIfNeeded()
                    try? FileManager.default.createDirectory(at: store.dataURL, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(store.dataURL)
                }
                Spacer()
                Button("Stop") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
        .animation(.default, value: today)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.formatted()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Vandaag" }
        if cal.isDateInYesterday(date) { return "Gisteren" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().locale(Locale(identifier: "nl_NL")))
    }

    private func recordLabel(_ key: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return key }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "nl_NL")))
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Muisklikkert: start bij inloggen wijzigen mislukt: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
