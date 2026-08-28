import Foundation

struct CodexUsageWindow: Equatable {
    let usedPercent: Double
    let resetAt: Date?
    let limitWindowSeconds: Double?

    var percentageText: String {
        "\(Int(usedPercent.rounded())) %"
    }

    func resetText(relativeTo date: Date = .now) -> String {
        guard let resetAt else { return "Zeitpunkt nicht verfügbar" }

        let seconds = max(0, Int(resetAt.timeIntervalSince(date)))
        guard seconds > 0 else { return "wird zurückgesetzt" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "in \(days) T. \(hours) Std." : "in \(days) T."
        }

        if hours > 0 {
            return minutes > 0 ? "in \(hours) Std. \(minutes) Min." : "in \(hours) Std."
        }

        return "in \(max(minutes, 1)) Min."
    }

    func resetDateTimeText(relativeTo date: Date = .now) -> String {
        guard let resetAt else { return "Zeitpunkt nicht verfügbar" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = .autoupdatingCurrent

        if Calendar.autoupdatingCurrent.isDate(resetAt, inSameDayAs: date) {
            formatter.dateFormat = "HH:mm"
            return "Heute um \(formatter.string(from: resetAt))"
        }

        formatter.dateFormat = "d. MMMM 'um' HH:mm"
        return formatter.string(from: resetAt)
    }
}

struct CodexUsageResetCredit: Equatable, Sendable {
    let availableCount: Int

    var isAvailable: Bool {
        availableCount > 0
    }
}

enum CodexUsageState: Equatable {
    case loading
    case available
    case unavailable(String)
}

struct CodexUsageSnapshot: Equatable {
    let primaryWindow: CodexUsageWindow?
    let weeklyWindow: CodexUsageWindow?
    let resetCredit: CodexUsageResetCredit?
    let state: CodexUsageState
    let capturedAt: Date?

    static let loading = CodexUsageSnapshot(
        primaryWindow: nil,
        weeklyWindow: nil,
        resetCredit: nil,
        state: .loading,
        capturedAt: nil
    )
}

/// Liest ausschließlich die von `codex login` angelegte Anmeldung und fragt
/// damit die aktuellen Limits des ChatGPT-Plans ab. Zugangsdaten werden weder
/// gespeichert, noch geloggt oder verändert.
@MainActor
final class CodexUsageService {
    var onStateUpdate: ((CodexUsageSnapshot) -> Void)?

    private var refreshTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    func start() {
        guard pollingTask == nil else { return }

        refresh()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        pollingTask?.cancel()
        refreshTask = nil
        pollingTask = nil
    }

    func refresh() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            let snapshot = await Self.fetchUsage()
            guard !Task.isCancelled else { return }
            self?.onStateUpdate?(snapshot)
            self?.refreshTask = nil
        }
    }

    private static func fetchUsage() async -> CodexUsageSnapshot {
        guard let credentials = readCredentials() else {
            return unavailable("Codex-Anmeldung nicht gefunden. Bitte einmal `codex login` ausführen.")
        }

        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            return unavailable("Codex-Limits konnten nicht abgerufen werden.")
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountID = credentials.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return unavailable("Codex-Limits konnten nicht abgerufen werden.")
            }

            switch httpResponse.statusCode {
            case 200..<300:
                let usage = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
                guard let rateLimit = usage.rateLimit else {
                    return unavailable("Für dieses Codex-Konto sind noch keine Limits verfügbar.")
                }

                let primary = makeWindow(rateLimit.primaryWindow)
                let weekly = makeWindow(rateLimit.secondaryWindow)
                guard primary != nil || weekly != nil else {
                    return unavailable("Für dieses Codex-Konto sind noch keine Limits verfügbar.")
                }

                let resetCredit = makeResetCredit(usage.rateLimitResetCredits)

                return CodexUsageSnapshot(
                    primaryWindow: primary,
                    weeklyWindow: weekly,
                    resetCredit: resetCredit,
                    state: .available,
                    capturedAt: .now
                )

            case 401, 403:
                return unavailable("Codex-Anmeldung ist abgelaufen. Bitte `codex login` erneut ausführen.")

            case 429:
                return unavailable("Der Abruf der Codex-Limits ist momentan begrenzt.")

            default:
                return unavailable("Codex-Limits konnten nicht abgerufen werden (HTTP \(httpResponse.statusCode)).")
            }
        } catch is DecodingError {
            return unavailable("Die Codex-Antwort konnte nicht gelesen werden.")
        } catch {
            return unavailable("Codex-Limits konnten wegen eines Netzwerkfehlers nicht abgerufen werden.")
        }
    }

    private static func unavailable(_ message: String) -> CodexUsageSnapshot {
        CodexUsageSnapshot(
            primaryWindow: nil,
            weeklyWindow: nil,
            resetCredit: nil,
            state: .unavailable(message),
            capturedAt: nil
        )
    }

    private static func makeWindow(_ window: CodexUsageResponse.Window?) -> CodexUsageWindow? {
        guard let usedPercent = window?.usedPercent else { return nil }

        return CodexUsageWindow(
            usedPercent: min(max(usedPercent, 0), 100),
            resetAt: window?.resetAt.map(Date.init(timeIntervalSince1970:)),
            limitWindowSeconds: window?.limitWindowSeconds
        )
    }

    private static func makeResetCredit(
        _ resetCredits: CodexUsageResponse.RateLimitResetCredits?
    ) -> CodexUsageResetCredit? {
        guard let resetCredits else { return nil }

        let credit = CodexUsageResetCredit(
            availableCount: max(resetCredits.availableCount ?? 0, 0)
        )

        return credit.isAvailable ? credit : nil
    }

    private static func readCredentials() -> CodexCredentials? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".codex/auth.json"),
            home.appendingPathComponent(".config/codex/auth.json")
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(CodexAuthFile.self, from: data),
                  let accessToken = file.tokens?.accessToken ?? file.accessToken,
                  !accessToken.isEmpty else {
                continue
            }

            return CodexCredentials(
                accessToken: accessToken,
                accountID: file.tokens?.accountID ?? file.accountID
            )
        }

        return nil
    }
}

private struct CodexCredentials {
    let accessToken: String
    let accountID: String?
}

private struct CodexAuthFile: Decodable {
    struct Tokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }

    let tokens: Tokens?
    let accessToken: String?
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case tokens
        case accessToken = "access_token"
        case accountID = "account_id"
    }
}

private struct CodexUsageResponse: Decodable {
    struct Window: Decodable {
        let usedPercent: Double?
        let resetAt: TimeInterval?
        let limitWindowSeconds: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }
    }

    struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct RateLimitResetCredits: Decodable {
        let availableCount: Int?

        enum CodingKeys: String, CodingKey {
            case availableCount = "available_count"
        }
    }

    let rateLimit: RateLimit?
    let rateLimitResetCredits: RateLimitResetCredits?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }
}
