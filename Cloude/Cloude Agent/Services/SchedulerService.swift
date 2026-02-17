import Foundation
import CloudeShared

@MainActor
class SchedulerService: ObservableObject {
    static let shared = SchedulerService()

    @Published var tasks: [ScheduledTask] = []

    var runnerManager: RunnerManager?
    var onTaskUpdated: ((ScheduledTask) -> Void)?

    private var timers: [String: DispatchSourceTimer] = [:]
    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Cloude")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("scheduled_tasks.json")

        loadTasks()
        restoreTimers()
    }

    func addTask(name: String, prompt: String, schedule: TaskSchedule, workingDirectory: String?) -> ScheduledTask? {
        if case .oneTime(let date) = schedule, date <= Date() {
            Log.info("SchedulerService: rejected one-time task with past date")
            return nil
        }

        if case .recurring(let cron) = schedule, !CronParser.isValid(cron) {
            Log.info("SchedulerService: rejected invalid cron '\(cron)'")
            return nil
        }

        let convId = UUID().uuidString
        let task = ScheduledTask(
            id: UUID().uuidString,
            name: name,
            prompt: prompt,
            schedule: schedule,
            conversationId: convId,
            isActive: true,
            nextRun: nextRunDate(for: schedule),
            createdAt: Date(),
            workingDirectory: workingDirectory
        )
        tasks.append(task)
        saveTasks()
        scheduleTimer(for: task)
        return task
    }

    func toggleTask(taskId: String, isActive: Bool) -> ScheduledTask? {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        tasks[idx].isActive = isActive

        if isActive {
            tasks[idx].nextRun = nextRunDate(for: tasks[idx].schedule)
            scheduleTimer(for: tasks[idx])
        } else {
            cancelTimer(for: taskId)
            tasks[idx].nextRun = nil
        }
        saveTasks()
        return tasks[idx]
    }

    func deleteTask(taskId: String) {
        cancelTimer(for: taskId)
        tasks.removeAll { $0.id == taskId }
        saveTasks()
    }

    func getAllTasks() -> [ScheduledTask] {
        tasks
    }

    private func executeTask(_ task: ScheduledTask) {
        guard let runnerManager else {
            Log.error("SchedulerService: no runnerManager")
            return
        }

        Log.info("SchedulerService: executing task '\(task.name)' (id=\(task.id.prefix(8)))")

        let workingDir = task.workingDirectory ?? MemoryService.projectRoot
        let needsCreate = task.lastRun == nil

        runnerManager.run(
            prompt: task.prompt,
            workingDirectory: workingDir,
            sessionId: task.conversationId,
            isNewSession: needsCreate,
            imagesBase64: nil,
            conversationId: task.conversationId,
            useFixedSessionId: true,
            model: "sonnet"
        )

        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].lastRun = Date()
            switch task.schedule {
            case .oneTime:
                tasks[idx].isActive = false
                tasks[idx].nextRun = nil
                cancelTimer(for: task.id)
            case .recurring:
                tasks[idx].nextRun = nextRunDate(for: task.schedule)
                scheduleTimer(for: tasks[idx])
            }
            saveTasks()
            onTaskUpdated?(tasks[idx])
        }
    }

    private func scheduleTimer(for task: ScheduledTask) {
        cancelTimer(for: task.id)
        guard task.isActive else { return }

        guard let fireDate = nextRunDate(for: task.schedule) else { return }
        let delay = max(fireDate.timeIntervalSinceNow, 1)

        let taskId = task.id
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let current = self.tasks.first(where: { $0.id == taskId }), current.isActive {
                    self.executeTask(current)
                }
            }
        }
        timer.resume()
        timers[task.id] = timer
    }

    private func cancelTimer(for taskId: String) {
        timers[taskId]?.cancel()
        timers.removeValue(forKey: taskId)
    }

    private func restoreTimers() {
        for task in tasks where task.isActive {
            scheduleTimer(for: task)
        }
        Log.info("SchedulerService: restored timers for \(tasks.filter { $0.isActive }.count) active tasks")
    }

    private func nextRunDate(for schedule: TaskSchedule) -> Date? {
        switch schedule {
        case .oneTime(let date):
            return date > Date() ? date : nil
        case .recurring(let cron):
            return CronParser.nextDate(from: cron, after: Date())
        }
    }

    private func loadTasks() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ScheduledTask].self, from: data) else { return }
        tasks = decoded
        Log.info("SchedulerService: loaded \(tasks.count) tasks")
    }

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}

enum CronParser {
    static func isValid(_ cron: String) -> Bool {
        let parts = cron.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return false }

        let ranges = [(0, 59), (0, 23), (1, 31), (1, 12), (0, 6)]
        for (field, range) in zip(parts, ranges) {
            if !isValidField(field, min: range.0, max: range.1) { return false }
        }
        return true
    }

    private static func isValidField(_ field: String, min: Int, max: Int) -> Bool {
        if field == "*" { return true }

        if field.contains("/") {
            let parts = field.split(separator: "/")
            guard parts.count == 2, let step = Int(parts[1]), step > 0 else { return false }
            return parts[0] == "*" || (Int(parts[0]).map { $0 >= min && $0 <= max } ?? false)
        }

        for part in field.split(separator: ",") {
            let str = String(part)
            if str.contains("-") {
                let range = str.split(separator: "-").compactMap { Int($0) }
                guard range.count == 2, range[0] >= min, range[1] <= max, range[0] <= range[1] else { return false }
            } else {
                guard let val = Int(str), val >= min, val <= max else { return false }
            }
        }
        return true
    }

    static func nextDate(from cron: String, after date: Date) -> Date? {
        let parts = cron.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return nil }

        let calendar = Calendar.current
        var candidate = calendar.date(byAdding: .minute, value: 1, to: date)!
        candidate = calendar.date(bySetting: .second, value: 0, of: candidate)!

        for _ in 0..<525960 {
            let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: candidate)
            guard let minute = components.minute,
                  let hour = components.hour,
                  let day = components.day,
                  let month = components.month,
                  let weekday = components.weekday else { return nil }

            let cronWeekday = weekday == 1 ? 0 : weekday - 1

            if matches(parts[4], value: cronWeekday) &&
               matches(parts[3], value: month) &&
               matches(parts[2], value: day) &&
               matches(parts[1], value: hour) &&
               matches(parts[0], value: minute) {
                return candidate
            }

            candidate = calendar.date(byAdding: .minute, value: 1, to: candidate)!
        }
        return nil
    }

    private static func matches(_ field: String, value: Int) -> Bool {
        if field == "*" { return true }

        if field.contains("/") {
            let parts = field.split(separator: "/")
            guard parts.count == 2, let step = Int(parts[1]) else { return false }
            let base = parts[0] == "*" ? 0 : (Int(parts[0]) ?? 0)
            return (value - base) >= 0 && (value - base) % step == 0
        }

        if field.contains(",") {
            return field.split(separator: ",").compactMap { Int($0) }.contains(value)
        }

        if field.contains("-") {
            let range = field.split(separator: "-").compactMap { Int($0) }
            if range.count == 2 { return value >= range[0] && value <= range[1] }
        }

        return Int(field) == value
    }
}
