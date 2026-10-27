import AppKit
import Combine
import Foundation

@MainActor
public final class AIUsageViewModel: ObservableObject {
    @Published public private(set) var providers: [AIProviderUsage] = []
    @Published public var selectedProvider: AIProviderType = .gemini

    private let service: AIUsageService
    private var probeTimer: Timer?

    public init(service: AIUsageService = AIUsageService()) {
        self.service = service
        self.providers = service.loadProviders()
        startOllamaProbeTimer()
        Task {
            await refreshLiveStatuses()
        }
    }

    public var currentSelectedUsage: AIProviderUsage {
        providers.first(where: { $0.provider == selectedProvider }) ?? providers[0]
    }

    public var averageRemainingPercentInt: Int {
        guard !providers.isEmpty else { return 100 }
        let sum = providers.reduce(0.0) { $0 + $1.remainingPercent }
        return Int(((sum / Double(providers.count)) * 100.0).rounded())
    }

    public func refreshLiveStatuses() async {
        let ollamaState = await service.probeLocalOllamaStatus()
        if let idx = providers.firstIndex(where: { $0.provider == .ollama }) {
            var item = providers[idx]
            item.isOnline = ollamaState.isRunning
            if ollamaState.isRunning {
                item.planName = "\(ollamaState.modelCount) models • \(ollamaState.activeModels) loaded"
                item.usedUnits = ollamaState.vramPercentUsed
                item.totalUnits = 100
                item.statusBadge = "\(100 - ollamaState.vramPercentUsed)% free"
                item.resetDescription = "127.0.0.1:11434 Online"
            } else {
                item.planName = "Local Daemon Idle"
                item.usedUnits = 0
                item.totalUnits = 100
                item.statusBadge = "100% free"
                item.resetDescription = "Run `ollama serve`"
            }
            providers[idx] = item
        }
        service.saveProviders(providers)
    }

    public func recordUsage(for provider: AIProviderType, delta: Int = 1) {
        guard let idx = providers.firstIndex(where: { $0.provider == provider }) else { return }
        var item = providers[idx]
        item.usedUnits = min(max(0, item.usedUnits + delta), item.totalUnits)
        item.statusBadge = "\(item.remainingPercentInt)% left"
        providers[idx] = item
        service.saveProviders(providers)
    }

    public func setRemainingFraction(for provider: AIProviderType, remainingFraction: Double) {
        guard let idx = providers.firstIndex(where: { $0.provider == provider }) else { return }
        let clamped = min(max(remainingFraction, 0.0), 1.0)
        var item = providers[idx]
        let remaining = Int((Double(item.totalUnits) * clamped).rounded())
        item.usedUnits = max(0, item.totalUnits - remaining)
        item.statusBadge = "\(item.remainingPercentInt)% left"
        providers[idx] = item
        service.saveProviders(providers)
    }

    public func resetQuota(for provider: AIProviderType) {
        guard let idx = providers.firstIndex(where: { $0.provider == provider }) else { return }
        var item = providers[idx]
        item.usedUnits = 0
        item.statusBadge = "100% left"
        providers[idx] = item
        service.saveProviders(providers)
    }

    private func startOllamaProbeTimer() {
        probeTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshLiveStatuses()
            }
        }
    }
}
