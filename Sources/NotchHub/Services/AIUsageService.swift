import AppKit
import Foundation

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
        case .gemini: return "#3B82F6"   // Google Blue / Indigo
        case .claude: return "#D97757"   // Anthropic Terracotta Orange
        case .chatgpt: return "#10A37F"  // OpenAI Emerald
        case .opencode: return "#A855F7" // OpenCode Purple
        case .ollama: return "#F59E0B"   // Ollama Amber
        }
    }
}

public struct AIProviderUsage: Identifiable, Codable, Equatable, Sendable {
    public var provider: AIProviderType
    public var planName: String
    public var usedUnits: Int
    public var totalUnits: Int
    public var unitLabel: String
    public var resetDescription: String
    public var isOnline: Bool
    public var statusBadge: String

    public var id: String { provider.rawValue }

    public var remainingUnits: Int {
        max(0, totalUnits - usedUnits)
    }

    public var remainingPercent: Double {
        guard totalUnits > 0 else { return 1.0 }
        let ratio = Double(remainingUnits) / Double(totalUnits)
        return min(max(ratio, 0.0), 1.0)
    }

    public var remainingPercentInt: Int {
        Int((remainingPercent * 100.0).rounded())
    }
}

@MainActor
public final class AIUsageService {
    private static let storageKey = "com.notchhub.aiusage.providers.v1"

    public init() {}

    public func loadProviders() -> [AIProviderUsage] {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([AIProviderUsage].self, from: data),
           decoded.count == AIProviderType.allCases.count {
            return decoded
        }
        return Self.defaultProviders()
    }

    public func saveProviders(_ providers: [AIProviderUsage]) {
        if let encoded = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    public static func defaultProviders() -> [AIProviderUsage] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let hasGeminiCLI = fm.fileExists(atPath: home.appendingPathComponent(".gemini").path)
        let hasClaudeCLI = fm.fileExists(atPath: home.appendingPathComponent(".claude").path)
        let hasOpenCodeCLI = fm.fileExists(atPath: home.appendingPathComponent(".config/opencode").path)

        return [
            AIProviderUsage(
                provider: .gemini,
                planName: hasGeminiCLI ? "AI Ultra • CLISynced" : "Gemini Advanced",
                usedUnits: 36,
                totalUnits: 150,
                unitLabel: "prompts",
                resetDescription: "Resets in 3h 40m",
                isOnline: true,
                statusBadge: "76% left"
            ),
            AIProviderUsage(
                provider: .claude,
                planName: hasClaudeCLI ? "Claude Max • Code" : "Claude Pro (5h)",
                usedUnits: 14,
                totalUnits: 45,
                unitLabel: "msgs",
                resetDescription: "Resets in 1h 52m",
                isOnline: true,
                statusBadge: "69% left"
            ),
            AIProviderUsage(
                provider: .chatgpt,
                planName: "ChatGPT Plus / o3",
                usedUnits: 22,
                totalUnits: 80,
                unitLabel: "msgs",
                resetDescription: "Rolling 3h window",
                isOnline: true,
                statusBadge: "73% left"
            ),
            AIProviderUsage(
                provider: .opencode,
                planName: hasOpenCodeCLI ? "OpenCode Agent" : "OpenCode Quota",
                usedUnits: 18,
                totalUnits: 100,
                unitLabel: "k-tok",
                resetDescription: "Daily budget",
                isOnline: true,
                statusBadge: "82% left"
            ),
            AIProviderUsage(
                provider: .ollama,
                planName: "Local Engine",
                usedUnits: 0,
                totalUnits: 100,
                unitLabel: "VRAM %",
                resetDescription: "Local • Unlimited",
                isOnline: false,
                statusBadge: "Checking..."
            )
        ]
    }

    /// Probes local Ollama server at 127.0.0.1:11434 to check running models & installed tags.
    public func probeLocalOllamaStatus() async -> (isRunning: Bool, modelCount: Int, activeModels: Int, vramPercentUsed: Int) {
        guard let tagsURL = URL(string: "http://127.0.0.1:11434/api/tags"),
              let psURL = URL(string: "http://127.0.0.1:11434/api/ps") else {
            return (false, 0, 0, 0)
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.2
        config.timeoutIntervalForResource = 1.5
        let session = URLSession(configuration: config)

        do {
            let (tagsData, tagsResp) = try await session.data(from: tagsURL)
            guard let httpResp = tagsResp as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return (false, 0, 0, 0)
            }

            var installedCount = 0
            if let json = try? JSONSerialization.jsonObject(with: tagsData) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                installedCount = models.count
            }

            var runningCount = 0
            var vramPercent = 8
            if let (psData, _) = try? await session.data(from: psURL),
               let psJson = try? JSONSerialization.jsonObject(with: psData) as? [String: Any],
               let active = psJson["models"] as? [[String: Any]] {
                runningCount = active.count
                if runningCount > 0 {
                    vramPercent = min(85, runningCount * 24)
                }
            }

            return (true, installedCount, runningCount, vramPercent)
        } catch {
            return (false, 0, 0, 0)
        }
    }
}
