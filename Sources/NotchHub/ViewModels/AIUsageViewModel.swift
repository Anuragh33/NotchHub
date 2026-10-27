import AppKit
import Combine
import Foundation

@MainActor
public final class AIUsageViewModel: ObservableObject {
    @Published public private(set) var providers: [AIProviderUsage] = []
    @Published public var selectedProvider: AIProviderType = .gemini
    @Published public var signInSelectedProvider: AIProviderType = .claude
    @Published public var signInTokenInput: String = ""
    @Published public var signInStatusBanner: String = "Sign in below via the web view, launch the CLI login, or paste an OAuth/API token."
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncedAt: Date?

    private let service: AIUsageService
    private var syncTimer: Timer?

    public init(service: AIUsageService = AIUsageService()) {
        self.service = service
        self.providers = AIProviderType.allCases.map { provider in
            AIProviderUsage(
                provider: provider,
                accountIdentifier: "Syncing...",
                planName: "Syncing System Account...",
                usedUnits: 0,
                totalUnits: 100,
                unitLabel: "%",
                resetDescription: "Scanning local credentials...",
                isAuthenticated: false,
                needsSignIn: false,
                liveTelemetrySummary: "Syncing..."
            )
        }
        startPeriodicSync()
        Task {
            await refreshLiveStatuses()
        }
    }

    public var currentSelectedUsage: AIProviderUsage {
        providers.first(where: { $0.provider == selectedProvider }) ?? providers[0]
    }

    public var averageRemainingPercentInt: Int {
        let authenticatedProviders = providers.filter(\.isAuthenticated)
        guard !authenticatedProviders.isEmpty else { return 0 }
        let sum = authenticatedProviders.reduce(0.0) { $0 + $1.remainingPercent }
        return Int(((sum / Double(authenticatedProviders.count)) * 100.0).rounded())
    }

    public var authenticatedCount: Int {
        providers.filter(\.isAuthenticated).count
    }

    public func refreshLiveStatuses() async {
        isSyncing = true
        let updated = await service.syncAllSystemAccounts()
        self.providers = updated
        self.lastSyncedAt = Date()
        isSyncing = false
    }

    public func openSignInWindow(for provider: AIProviderType? = nil) {
        let target = provider ?? selectedProvider
        signInSelectedProvider = target
        signInTokenInput = customToken(for: target) ?? ""
        signInStatusBanner = "Sign in below via the web view, launch the CLI login, or paste an OAuth/API token."
        AIAccountSignInWindowController.shared.presentSignIn(for: target, viewModel: self)
    }

    public func customToken(for provider: AIProviderType) -> String? {
        service.customToken(for: provider)
    }

    public func saveCustomToken(_ token: String, for provider: AIProviderType) {
        service.setCustomToken(token, for: provider)
        Task {
            await refreshLiveStatuses()
        }
    }

    public func markWebSessionConnected(for provider: AIProviderType) {
        service.markWebSignedIn(true, for: provider)
        Task {
            await refreshLiveStatuses()
        }
    }

    public func launchTerminalCLILogin(for provider: AIProviderType) {
        let cmd = provider.cliLoginCommand
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(cmd)"
        end tell
        """
        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            if let script = NSAppleScript(source: appleScript) {
                _ = script.executeAndReturnError(&error)
            }
        }
    }

    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshLiveStatuses()
            }
        }
    }
}
