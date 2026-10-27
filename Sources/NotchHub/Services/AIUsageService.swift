import AppKit
import Foundation
import SQLite3
import WebKit

public enum AIProviderType: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini = "Gemini"
    case claude = "Claude"
    case chatgpt = "ChatGPT"
    case opencode = "OpenCode"
    case ollama = "Ollama"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .gemini: return "sparkles"
        case .claude: return "brain.head.profile"
        case .chatgpt: return "bubble.left.and.bubble.right.fill"
        case .opencode: return "terminal.fill"
        case .ollama: return "cpu.fill"
        }
    }

    public var accentHex: String {
        switch self {
        case .gemini: return "#3B82F6"   // Google Blue
        case .claude: return "#D97757"   // Anthropic Terracotta
        case .chatgpt: return "#10A37F"  // OpenAI Emerald
        case .opencode: return "#A855F7" // OpenCode Purple
        case .ollama: return "#F59E0B"   // Ollama Amber
        }
    }

    public var signInURL: URL {
        switch self {
        case .gemini: return URL(string: "https://aistudio.google.com/")!
        case .claude: return URL(string: "https://claude.ai/login")!
        case .chatgpt: return URL(string: "https://chatgpt.com/")!
        case .opencode: return URL(string: "https://opencode.ai/")!
        case .ollama: return URL(string: "http://127.0.0.1:11434/")!
        }
    }

    public var cliLoginCommand: String {
        switch self {
        case .gemini: return "gemini"
        case .claude: return "claude auth login"
        case .chatgpt: return "codex login"
        case .opencode: return "opencode auth login"
        case .ollama: return "ollama serve"
        }
    }
}

public struct AIProviderUsage: Identifiable, Codable, Equatable, Sendable {
    public var provider: AIProviderType
    public var accountIdentifier: String
    public var planName: String
    public var usedUnits: Int
    public var totalUnits: Int
    public var unitLabel: String
    public var resetDescription: String
    public var isAuthenticated: Bool
    public var needsSignIn: Bool
    public var liveTelemetrySummary: String

    public var id: String { provider.rawValue }

    public var remainingUnits: Int {
        max(0, totalUnits - usedUnits)
    }

    public var remainingPercent: Double {
        guard totalUnits > 0 else { return isAuthenticated ? 1.0 : 0.0 }
        let ratio = Double(remainingUnits) / Double(totalUnits)
        return min(max(ratio, 0.0), 1.0)
    }

    public var remainingPercentInt: Int {
        Int((remainingPercent * 100.0).rounded())
    }
}

@MainActor
public final class AIUsageService {
    private static let customTokenPrefix = "com.notchhub.ai.token."
    private static let webSignedInPrefix = "com.notchhub.ai.websignedin."

    public init() {}

    public func setCustomToken(_ token: String, for provider: AIProviderType) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.customTokenPrefix + provider.rawValue)
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.customTokenPrefix + provider.rawValue)
        }
    }

    public func customToken(for provider: AIProviderType) -> String? {
        UserDefaults.standard.string(forKey: Self.customTokenPrefix + provider.rawValue)
    }

    public func markWebSignedIn(_ signedIn: Bool, for provider: AIProviderType) {
        UserDefaults.standard.set(signedIn, forKey: Self.webSignedInPrefix + provider.rawValue)
    }

    public func isWebSignedIn(for provider: AIProviderType) -> Bool {
        UserDefaults.standard.bool(forKey: Self.webSignedInPrefix + provider.rawValue)
    }

    /// Synchronizes all 5 AI providers with real system accounts, SQLite databases, OAuth APIs, and local daemons.
    public func syncAllSystemAccounts() async -> [AIProviderUsage] {
        async let geminiUsage = syncGeminiAccount()
        async let claudeUsage = syncClaudeAccount()
        async let chatgptUsage = syncChatGPTAccount()
        async let opencodeUsage = syncOpenCodeAccount()
        async let ollamaUsage = syncOllamaAccount()

        return await [
            geminiUsage,
            claudeUsage,
            chatgptUsage,
            opencodeUsage,
            ollamaUsage
        ]
    }

    // MARK: - 1. Gemini System Account & Antigravity / CLI Telemetry Sync

    private func syncGeminiAccount() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let geminiDir = home.appendingPathComponent(".gemini")
        let accountsFile = geminiDir.appendingPathComponent("google_accounts.json")
        let oauthFile = geminiDir.appendingPathComponent("oauth_creds.json")

        var activeEmail: String?
        if let data = try? Data(contentsOf: accountsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = json["active"] as? String, !active.isEmpty {
            activeEmail = active
        }

        var hasOAuth = fm.fileExists(atPath: oauthFile.path)
        if let custom = customToken(for: .gemini), !custom.isEmpty {
            hasOAuth = true
            if activeEmail == nil { activeEmail = "API Key Configured" }
        }
        if isWebSignedIn(for: .gemini) {
            hasOAuth = true
            if activeEmail == nil { activeEmail = "Web Session Active" }
        }

        // Count real user prompts & planner steps in ~/.gemini/antigravity/brain/*/.system_generated/logs/transcript.jsonl
        let windowStats = await Task.detached(priority: .utility) { () -> (recentPrompts: Int, totalPrompts: Int, totalSteps: Int) in
            let brainDir = geminiDir.appendingPathComponent("antigravity/brain")
            guard let convDirs = try? FileManager.default.contentsOfDirectory(
                at: brainDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                return (0, 0, 0)
            }

            let fiveHoursAgo = Date().addingTimeInterval(-5.0 * 3600.0)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackFormatter = ISO8601DateFormatter()

            var recentPrompts = 0
            var totalPrompts = 0
            var totalSteps = 0

            for dir in convDirs {
                let transcriptURL = dir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                guard let content = try? String(contentsOf: transcriptURL, encoding: .utf8) else { continue }
                let lines = content.split(separator: "\n")
                totalSteps += lines.count

                for line in lines {
                    guard line.contains("\"USER_INPUT\"") else { continue }
                    totalPrompts += 1
                    if let data = line.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let createdAt = obj["created_at"] as? String {
                        let date = isoFormatter.date(from: createdAt) ?? fallbackFormatter.date(from: createdAt)
                        if let date, date >= fiveHoursAgo {
                            recentPrompts += 1
                        }
                    }
                }
            }
            return (recentPrompts, totalPrompts, totalSteps)
        }.value

        let windowLimit = 150 // Rolling 5-hour high-tier prompt quota
        let authenticated = (activeEmail != nil) || hasOAuth
        let usedInWindow = min(windowStats.recentPrompts, windowLimit)

        return AIProviderUsage(
            provider: .gemini,
            accountIdentifier: activeEmail ?? "Not Signed In",
            planName: authenticated ? "Google AI • \(activeEmail ?? "Connected")" : "Sign In Required",
            usedUnits: authenticated ? usedInWindow : 0,
            totalUnits: windowLimit,
            unitLabel: "prompts (5h)",
            resetDescription: authenticated ? "\(windowStats.totalPrompts) total prompts • \(windowStats.totalSteps) steps" : "Click Sign In to connect",
            isAuthenticated: authenticated,
            needsSignIn: !authenticated,
            liveTelemetrySummary: authenticated
                ? "Synced ~/.gemini (\(windowStats.recentPrompts) prompts in 5h window)"
                : "No ~/.gemini account found"
        )
    }

    // MARK: - 2. ChatGPT / Codex Live OAuth API (`wham/usage`) & SQLite Sync

    private func syncChatGPTAccount() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let codexDir = home.appendingPathComponent(".codex")
        let authFile = codexDir.appendingPathComponent("auth.json")
        let sqliteFile = codexDir.appendingPathComponent("state_5.sqlite")

        // Query real token usage & thread count from ~/.codex/state_5.sqlite
        let localDBStats = await Task.detached(priority: .utility) { () -> (threads: Int, totalTokens: Int64) in
            guard FileManager.default.fileExists(atPath: sqliteFile.path) else { return (0, 0) }
            var db: OpaquePointer?
            guard sqlite3_open_v2(sqliteFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                if db != nil { sqlite3_close(db) }
                return (0, 0)
            }
            defer { sqlite3_close(db) }

            var stmt: OpaquePointer?
            let sql = "SELECT COUNT(*), COALESCE(SUM(tokens_used), 0) FROM threads;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return (0, 0) }
            defer { sqlite3_finalize(stmt) }

            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = Int(sqlite3_column_int(stmt, 0))
                let tokens = sqlite3_column_int64(stmt, 1)
                return (count, tokens)
            }
            return (0, 0)
        }.value

        var accessToken: String? = customToken(for: .chatgpt)
        var accountId: String?
        var email: String?
        var planType: String = "connected"

        if let data = try? Data(contentsOf: authFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = json["tokens"] as? [String: Any] {
            if accessToken == nil {
                accessToken = tokens["access_token"] as? String
            }
            accountId = tokens["account_id"] as? String
        }

        // Call live https://chatgpt.com/backend-api/wham/usage if we have a token
        if let token = accessToken, !token.isEmpty {
            if let liveWham = await fetchChatGPTWhamUsage(accessToken: token, accountId: accountId) {
                email = liveWham.email
                planType = liveWham.planType.capitalized
                let usedPct = min(max(liveWham.usedPercent, 0), 100)
                let tokenMillions = Double(localDBStats.totalTokens) / 1_000_000.0
                let resetHrs = max(1, liveWham.resetAfterSeconds / 3600)

                return AIProviderUsage(
                    provider: .chatgpt,
                    accountIdentifier: email ?? "ChatGPT Account",
                    planName: "ChatGPT \(planType) • \(email ?? "Synced")",
                    usedUnits: usedPct,
                    totalUnits: 100,
                    unitLabel: "% window used",
                    resetDescription: String(format: "%.2fM tok (%d threads) • %dh window", tokenMillions, localDBStats.threads, resetHrs),
                    isAuthenticated: true,
                    needsSignIn: false,
                    liveTelemetrySummary: "Live OpenAI wham/usage API + ~/.codex SQLite"
                )
            }
        }

        let hasWeb = isWebSignedIn(for: .chatgpt)
        let hasLocalDB = localDBStats.threads > 0
        let authenticated = hasWeb || hasLocalDB
        let tokenMillions = Double(localDBStats.totalTokens) / 1_000_000.0

        return AIProviderUsage(
            provider: .chatgpt,
            accountIdentifier: authenticated ? "Codex Local Account" : "Not Signed In",
            planName: authenticated ? "ChatGPT / Codex (\(localDBStats.threads) threads)" : "Sign In Required",
            usedUnits: authenticated ? min(100, Int((tokenMillions / 15.0) * 100.0)) : 0,
            totalUnits: 100,
            unitLabel: "% quota",
            resetDescription: authenticated ? String(format: "%.2fM tokens used locally", tokenMillions) : "Click Sign In to connect",
            isAuthenticated: authenticated,
            needsSignIn: !authenticated,
            liveTelemetrySummary: authenticated ? "Synced ~/.codex/state_5.sqlite" : "No ChatGPT session"
        )
    }

    private func fetchChatGPTWhamUsage(
        accessToken: String,
        accountId: String?
    ) async -> (email: String?, planType: String, usedPercent: Int, resetAfterSeconds: Int)? {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("codex-cli/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let email = json["email"] as? String
            let planType = (json["plan_type"] as? String) ?? "free"
            var usedPercent = 0
            var resetAfter = 10800
            if let rateLimit = json["rate_limit"] as? [String: Any],
               let primary = rateLimit["primary_window"] as? [String: Any] {
                usedPercent = (primary["used_percent"] as? Int) ?? 0
                resetAfter = (primary["reset_after_seconds"] as? Int) ?? 10800
            }
            return (email, planType, usedPercent, resetAfter)
        } catch {
            return nil
        }
    }

    // MARK: - 3. Claude OAuth / Web Session & ~/.claude Telemetry Sync

    private func syncClaudeAccount() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude")
        let credsFile = claudeDir.appendingPathComponent(".credentials.json")
        let historyFile = claudeDir.appendingPathComponent("history.jsonl")

        // Count real history entries in ~/.claude/history.jsonl
        let historyStats = await Task.detached(priority: .utility) { () -> (recentCount: Int, totalCount: Int) in
            guard let content = try? String(contentsOf: historyFile, encoding: .utf8) else { return (0, 0) }
            let lines = content.split(separator: "\n")
            let fiveHoursAgoMs = (Date().timeIntervalSince1970 - 5.0 * 3600.0) * 1000.0
            var recent = 0
            for line in lines {
                if let data = line.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ts = obj["timestamp"] as? Double, ts >= fiveHoursAgoMs {
                    recent += 1
                }
            }
            return (recent, lines.count)
        }.value

        var oauthToken: String? = customToken(for: .claude)
        var tokenExpired = false

        if let data = try? Data(contentsOf: credsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauth = json["claudeAiOauth"] as? [String: Any] {
            if oauthToken == nil {
                oauthToken = oauth["accessToken"] as? String
            }
            if let expiresAtMs = oauth["expiresAt"] as? Double {
                let nowMs = Date().timeIntervalSince1970 * 1000.0
                if nowMs > expiresAtMs {
                    tokenExpired = true
                }
            }
        }

        // Try live Anthropic OAuth usage endpoint if token is present
        if let token = oauthToken, !token.isEmpty {
            if let liveUtilization = await fetchClaudeOAuthUsage(accessToken: token) {
                let usedPct = min(max(Int(liveUtilization.fiveHourPercent.rounded()), 0), 100)
                return AIProviderUsage(
                    provider: .claude,
                    accountIdentifier: "Claude OAuth Synced",
                    planName: "Claude Code • 5h Window",
                    usedUnits: usedPct,
                    totalUnits: 100,
                    unitLabel: "% used (5h)",
                    resetDescription: "\(historyStats.totalCount) local prompts • Live OAuth",
                    isAuthenticated: true,
                    needsSignIn: false,
                    liveTelemetrySummary: "Live api.anthropic.com/api/oauth/usage"
                )
            }
        }

        // Check if signed in via built-in WebKit Sign-In window
        if isWebSignedIn(for: .claude) {
            let limit = 45
            let used = min(limit, historyStats.recentCount)
            return AIProviderUsage(
                provider: .claude,
                accountIdentifier: "claude.ai Web Session",
                planName: "Claude Web + CLI (\(historyStats.totalCount) msgs)",
                usedUnits: used,
                totalUnits: limit,
                unitLabel: "msgs (5h)",
                resetDescription: "\(historyStats.recentCount) msgs in last 5h • \(historyStats.totalCount) total",
                isAuthenticated: true,
                needsSignIn: false,
                liveTelemetrySummary: "Synced claude.ai session & ~/.claude/history.jsonl"
            )
        }

        // If ~/.claude/.credentials.json exists but token is expired or unauthorized, prompt user to Sign In
        let statusText = tokenExpired
            ? "OAuth Token Expired • \(historyStats.totalCount) past msgs"
            : (historyStats.totalCount > 0 ? "Sign In to refresh (\(historyStats.totalCount) local msgs)" : "Click Sign In to connect Claude")

        return AIProviderUsage(
            provider: .claude,
            accountIdentifier: tokenExpired ? "Session Expired" : "Sign In Required",
            planName: "Claude • Sign In Needed",
            usedUnits: historyStats.recentCount,
            totalUnits: 45,
            unitLabel: "msgs (5h)",
            resetDescription: statusText,
            isAuthenticated: false,
            needsSignIn: true,
            liveTelemetrySummary: statusText
        )
    }

    private func fetchClaudeOAuthUsage(accessToken: String) async -> (fiveHourPercent: Double, sevenDayPercent: Double)? {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let fiveHour = (json["five_hour"] as? [String: Any])?["utilization"] as? Double ?? 0.0
            let sevenDay = (json["seven_day"] as? [String: Any])?["utilization"] as? Double ?? 0.0
            return (fiveHour, sevenDay)
        } catch {
            return nil
        }
    }

    // MARK: - 4. OpenCode Real SQLite Database (`opencode.db`) & `auth.json` Sync

    private func syncOpenCodeAccount() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let shareDir = home.appendingPathComponent(".local/share/opencode")
        let authFile = shareDir.appendingPathComponent("auth.json")
        let dbFile = shareDir.appendingPathComponent("opencode.db")

        var configuredProviders: [String] = []
        if let data = try? Data(contentsOf: authFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            configuredProviders = Array(json.keys).sorted()
        }

        let dbStats = await Task.detached(priority: .utility) { () -> (totalMessages: Int, recentMessages: Int, latestModel: String, recentTokensK: Int) in
            guard FileManager.default.fileExists(atPath: dbFile.path) else {
                return (0, 0, "None", 0)
            }
            var db: OpaquePointer?
            guard sqlite3_open_v2(dbFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                if db != nil { sqlite3_close(db) }
                return (0, 0, "None", 0)
            }
            defer { sqlite3_close(db) }

            var totalMessages = 0
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM message;", -1, &countStmt, nil) == SQLITE_OK {
                if sqlite3_step(countStmt) == SQLITE_ROW {
                    totalMessages = Int(sqlite3_column_int(countStmt, 0))
                }
            }
            sqlite3_finalize(countStmt)

            // Inspect latest 50 messages for active model and token sum
            var latestModel = "opencode"
            var recentTokens = 0
            var recentMessages = 0
            let dayAgoMs = Int64((Date().timeIntervalSince1970 - 86400.0) * 1000.0)

            var recentStmt: OpaquePointer?
            let query = "SELECT time_created, data FROM message ORDER BY time_created DESC LIMIT 50;"
            if sqlite3_prepare_v2(db, query, -1, &recentStmt, nil) == SQLITE_OK {
                var isFirst = true
                while sqlite3_step(recentStmt) == SQLITE_ROW {
                    let timeCreated = sqlite3_column_int64(recentStmt, 0)
                    if timeCreated >= dayAgoMs {
                        recentMessages += 1
                    }
                    if let cString = sqlite3_column_text(recentStmt, 1) {
                        let jsonStr = String(cString: cString)
                        if let data = jsonStr.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if isFirst, let modelID = obj["modelID"] as? String, !modelID.isEmpty {
                                latestModel = modelID
                                isFirst = false
                            }
                            if let tokens = obj["tokens"] as? [String: Any],
                               let total = tokens["total"] as? Int {
                                recentTokens += total
                            }
                        }
                    }
                }
            }
            sqlite3_finalize(recentStmt)

            return (totalMessages, recentMessages, latestModel, max(1, recentTokens / 1000))
        }.value

        let isConnected = !configuredProviders.isEmpty || dbStats.totalMessages > 0 || (customToken(for: .opencode) != nil)
        let dailyLimitMsgs = 250
        let usedToday = min(dailyLimitMsgs, dbStats.recentMessages)
        let providersLabel = configuredProviders.isEmpty ? "Local DB" : configuredProviders.joined(separator: ", ")

        return AIProviderUsage(
            provider: .opencode,
            accountIdentifier: providersLabel,
            planName: isConnected ? "\(dbStats.latestModel) • \(providersLabel)" : "Sign In Required",
            usedUnits: isConnected ? usedToday : 0,
            totalUnits: dailyLimitMsgs,
            unitLabel: "msgs (24h)",
            resetDescription: isConnected
                ? "\(dbStats.totalMessages) total msgs • \(dbStats.recentTokensK)k recent tok"
                : "Click Sign In to connect OpenCode",
            isAuthenticated: isConnected,
            needsSignIn: !isConnected,
            liveTelemetrySummary: "Synced ~/.local/share/opencode/opencode.db (\(dbStats.totalMessages) msgs)"
        )
    }

    // MARK: - 5. Ollama Live Daemon (`127.0.0.1:11434`) & `~/.ollama/models` Sync

    private func syncOllamaAccount() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let manifestsDir = home.appendingPathComponent(".ollama/models/manifests/registry.ollama.ai/library")

        var diskModels: [String] = []
        if let items = try? fm.contentsOfDirectory(atPath: manifestsDir.path) {
            diskModels = items.filter { !$0.hasPrefix(".") }
        }

        guard let tagsURL = URL(string: "http://127.0.0.1:11434/api/tags"),
              let psURL = URL(string: "http://127.0.0.1:11434/api/ps") else {
            return AIProviderUsage(
                provider: .ollama,
                accountIdentifier: "127.0.0.1:11434",
                planName: "Ollama Local",
                usedUnits: 0,
                totalUnits: 100,
                unitLabel: "% VRAM",
                resetDescription: "Offline",
                isAuthenticated: false,
                needsSignIn: true,
                liveTelemetrySummary: "Offline"
            )
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2.0
        let session = URLSession(configuration: config)

        do {
            let (tagsData, tagsResp) = try await session.data(from: tagsURL)
            guard let httpResp = tagsResp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                throw URLError(.cannotConnectToHost)
            }

            var modelNames: [String] = []
            if let json = try? JSONSerialization.jsonObject(with: tagsData) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                modelNames = models.compactMap { $0["name"] as? String }
            }

            var activeNames: [String] = []
            var vramBytes: Int64 = 0
            if let (psData, _) = try? await session.data(from: psURL),
               let psJson = try? JSONSerialization.jsonObject(with: psData) as? [String: Any],
               let active = psJson["models"] as? [[String: Any]] {
                activeNames = active.compactMap { $0["name"] as? String }
                for m in active {
                    if let sizeVram = m["size_vram"] as? Int64 {
                        vramBytes += sizeVram
                    } else if let size = m["size"] as? Int64 {
                        vramBytes += size
                    }
                }
            }

            let vramGB = Double(vramBytes) / (1024.0 * 1024.0 * 1024.0)
            let vramPercent = min(95, Int((vramGB / 16.0) * 100.0))
            let firstModel = activeNames.first ?? modelNames.first ?? "Ready"

            return AIProviderUsage(
                provider: .ollama,
                accountIdentifier: "127.0.0.1:11434 Online",
                planName: "Ollama • \(modelNames.count) models (\(firstModel))",
                usedUnits: vramPercent,
                totalUnits: 100,
                unitLabel: "% VRAM",
                resetDescription: String(format: "%d active in VRAM (%.1f GB) • %d installed", activeNames.count, vramGB, modelNames.count),
                isAuthenticated: true,
                needsSignIn: false,
                liveTelemetrySummary: "Live 127.0.0.1:11434 (\(modelNames.count) models)"
            )
        } catch {
            let diskCount = diskModels.count
            let diskSummary = diskCount > 0
                ? "\(diskCount) models on disk (\(diskModels.prefix(2).joined(separator: ", "))) • Server stopped"
                : "Daemon stopped • Click Start / Connect"
            return AIProviderUsage(
                provider: .ollama,
                accountIdentifier: diskCount > 0 ? "\(diskCount) Local Models" : "Daemon Offline",
                planName: diskCount > 0 ? "Ollama (\(diskCount) models on disk)" : "Ollama Offline",
                usedUnits: 0,
                totalUnits: 100,
                unitLabel: "% VRAM",
                resetDescription: diskSummary,
                isAuthenticated: diskCount > 0,
                needsSignIn: diskCount == 0,
                liveTelemetrySummary: diskSummary
            )
        }
    }
}

public extension NSColor {
    convenience init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
