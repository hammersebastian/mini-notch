import Combine
import Foundation

/// Verwaltet die bekannten Activities und die aktuell ausgewählte Activity.
///
/// Die aktive Activity mit der höchsten Priorität wird angezeigt. Bei gleicher
/// Priorität bleibt die aktuelle Auswahl bestehen; wird sie entfernt oder
/// inaktiv, gewinnt die zuerst veröffentlichte gleichrangige Activity.
///
/// Der gemeinsame Lifecycle ist Snapshot-basiert:
/// - `publish` fügt eine neue ID hinzu oder aktualisiert den vorhandenen
///   Snapshot an seiner bisherigen Position.
/// - Änderungen von `isActive` aktivieren bzw. deaktivieren eine Activity beim
///   Veröffentlichen und lösen dieselbe zentrale Neuauswahl aus.
/// - Jede Veröffentlichung setzt die optionale Lebensdauer gemäß
///   `autoDismissAfter` neu; permanente Activities starten keinen Dismiss-Task.
/// - Explizites Entfernen, eine nichtpositive Lebensdauer und Auto-Dismiss
///   enden gemeinsam in `removeActivity(withID:)`.
@MainActor
final class ActivityManager: ObservableObject {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    @Published private(set) var activities: [any NotchActivity]
    @Published private(set) var currentActivityID: String?

    private let sleep: Sleep
    private var dismissTasks: [String: Task<Void, Never>] = [:]
    private var dismissTokens: [String: UUID] = [:]

    var activeActivities: [any NotchActivity] {
        activities.filter { $0.isActive }
    }

    var currentActivity: (any NotchActivity)? {
        guard let currentActivityID else { return nil }

        return activities.first {
            $0.id == currentActivityID && $0.isActive
        }
    }

    init(
        activities: [any NotchActivity] = [],
        selectedActivityID: String? = nil,
        sleep: @escaping Sleep = { duration in
            try await Task.sleep(for: .seconds(duration))
        }
    ) {
        var uniqueActivities: [any NotchActivity] = []

        for activity in activities {
            if let index = uniqueActivities.firstIndex(where: { $0.id == activity.id }) {
                uniqueActivities[index] = activity
            } else {
                uniqueActivities.append(activity)
            }
        }

        uniqueActivities.removeAll {
            guard let duration = $0.autoDismissAfter else { return false }
            return duration <= 0
        }

        self.activities = uniqueActivities
        self.sleep = sleep

        currentActivityID = Self.preferredActivityID(
            in: uniqueActivities,
            preserving: selectedActivityID
        )

        for activity in uniqueActivities {
            scheduleAutoDismissIfNeeded(for: activity)
        }
    }

    deinit {
        dismissTasks.values.forEach { $0.cancel() }
    }

    /// Fügt eine Activity hinzu oder ersetzt ihren bisherigen Snapshot. Eine
    /// erneute Veröffentlichung startet ihre optionale Lebensdauer vollständig
    /// neu.
    func publish(_ activity: any NotchActivity) {
        if let duration = activity.autoDismissAfter, duration <= 0 {
            removeActivity(withID: activity.id)
            return
        }

        cancelAutoDismiss(forActivityID: activity.id)

        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        } else {
            activities.append(activity)
        }

        reconcileCurrentActivity()
        scheduleAutoDismissIfNeeded(for: activity)
    }

    /// Entfernt eine Activity anhand ihrer stabilen Kennung.
    func removeActivity(withID id: String) {
        cancelAutoDismiss(forActivityID: id)

        guard let index = activities.firstIndex(where: { $0.id == id }) else {
            return
        }

        activities.remove(at: index)
        reconcileCurrentActivity()
    }

    /// Wählt eine bereits veröffentlichte und aktive Activity explizit aus,
    /// sofern keine andere aktive Activity eine höhere Priorität besitzt.
    @discardableResult
    func selectActivity(withID id: String) -> Bool {
        guard let activity = activities.first(where: { $0.id == id && $0.isActive }),
              let highestPriority = activeActivities.map(\.priority).max(),
              activity.priority == highestPriority else {
            return false
        }

        setCurrentActivityID(id)
        return true
    }

    private func reconcileCurrentActivity() {
        setCurrentActivityID(
            Self.preferredActivityID(
                in: activities,
                preserving: currentActivityID
            )
        )
    }

    private func setCurrentActivityID(_ id: String?) {
        guard currentActivityID != id else { return }
        currentActivityID = id
    }

    private func scheduleAutoDismissIfNeeded(for activity: any NotchActivity) {
        guard activity.isActive,
              let duration = activity.autoDismissAfter,
              duration > 0 else {
            return
        }

        let activityID = activity.id
        let token = UUID()
        let sleep = sleep

        dismissTokens[activityID] = token
        dismissTasks[activityID] = Task { @MainActor [weak self] in
            do {
                try await sleep(duration)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.dismissActivity(withID: activityID, token: token)
        }
    }

    private func cancelAutoDismiss(forActivityID id: String) {
        dismissTasks.removeValue(forKey: id)?.cancel()
        dismissTokens.removeValue(forKey: id)
    }

    private func dismissActivity(withID id: String, token: UUID) {
        guard dismissTokens[id] == token else { return }
        removeActivity(withID: id)
    }

    private static func preferredActivityID(
        in activities: [any NotchActivity],
        preserving currentActivityID: String?
    ) -> String? {
        let activeActivities = activities.filter(\.isActive)
        guard let highestPriority = activeActivities.map(\.priority).max() else {
            return nil
        }

        if let currentActivityID,
           activeActivities.contains(where: {
               $0.id == currentActivityID && $0.priority == highestPriority
           }) {
            return currentActivityID
        }

        return activeActivities.first(where: { $0.priority == highestPriority })?.id
    }
}
