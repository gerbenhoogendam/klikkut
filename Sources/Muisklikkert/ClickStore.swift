import AppKit
import Combine

/// Klikken van één kalenderdag.
struct DayStats: Codable, Equatable {
    var left = 0
    var right = 0
    var other = 0
    /// Aantal klikken per uur (0–23).
    var hours = [Int](repeating: 0, count: 24)

    var total: Int { left + right + other }
}

enum ClickButton {
    case left, right, other
}

/// Vangt alle muisklikken op (ook in andere apps) en houdt ze per dag bij.
@MainActor
final class ClickStore: ObservableObject {
    static let shared = ClickStore()

    /// Dagstatistieken, per datum ("yyyy-MM-dd").
    @Published private(set) var days: [String: DayStats] = [:]
    /// Wordt elke minuut bijgewerkt zodat de teller om middernacht omslaat.
    @Published private(set) var now = Date()

    private var monitors: [Any] = []
    private var timers: [Timer] = []
    private var isDirty = false

    let dataURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Muisklikkert", isDirectory: true)
    }()

    private var fileURL: URL { dataURL.appendingPathComponent("clicks.json") }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { keyFormatter.string(from: date) }

    // MARK: - Afgeleide waarden

    var today: DayStats { days[Self.key(for: now)] ?? DayStats() }

    /// Klikken in de laatste 24 uur (op uurniveau: dit uur + de 23 uur daarvoor).
    var last24Hours: Int {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let todayPart = today.hours[0...hour].reduce(0, +)
        let yesterdayHours = days[Self.key(for: yesterday)]?.hours ?? []
        let yesterdayPart = yesterdayHours.indices.filter { $0 > hour }.map { yesterdayHours[$0] }.reduce(0, +)
        return todayPart + yesterdayPart
    }

    /// De laatste `count` dagen, nieuwste eerst (vandaag inbegrepen).
    func recentDays(_ count: Int) -> [(date: Date, stats: DayStats)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        return (0..<count).map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: start)!
            return (date, days[Self.key(for: date)] ?? DayStats())
        }
    }

    var recordDay: (date: String, total: Int)? {
        days.max { $0.value.total < $1.value.total }.map { ($0.key, $0.value.total) }
    }

    // MARK: - Opstarten

    func start() {
        load()

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // Klikken in andere apps.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { ClickStore.shared.record(event) }
        }) {
            monitors.append(global)
        }
        // Klikken in Muisklikkert zelf (het menu) komen niet via de globale monitor binnen.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { ClickStore.shared.record(event) }
            return event
        }) {
            monitors.append(local)
        }

        timers.append(Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { ClickStore.shared.now = Date() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { ClickStore.shared.saveIfNeeded() }
        })
    }

    private func record(_ event: NSEvent) {
        let button: ClickButton
        switch event.type {
        case .leftMouseDown: button = .left
        case .rightMouseDown: button = .right
        default: button = .other
        }
        record(button, at: Date())
    }

    func record(_ button: ClickButton, at date: Date) {
        now = date
        let key = Self.key(for: date)
        var stats = days[key] ?? DayStats()
        switch button {
        case .left: stats.left += 1
        case .right: stats.right += 1
        case .other: stats.other += 1
        }
        stats.hours[Calendar.current.component(.hour, from: date)] += 1
        days[key] = stats
        isDirty = true
    }

    // MARK: - Opslag

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            days = try JSONDecoder().decode([String: DayStats].self, from: data)
        } catch {
            // Bewaar het onleesbare bestand zodat er niets verloren gaat.
            let backup = dataURL.appendingPathComponent("clicks-corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("Muisklikkert: kon clicks.json niet lezen (\(error)), verplaatst naar \(backup.path)")
        }
    }

    func saveIfNeeded() {
        guard isDirty else { return }
        do {
            try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(days).write(to: fileURL, options: .atomic)
            isDirty = false
        } catch {
            NSLog("Muisklikkert: opslaan mislukt: \(error)")
        }
    }
}
