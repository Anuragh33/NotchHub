import AppKit
import SwiftUI
import WebKit

@MainActor
public final class AIAccountSignInWindowController: NSObject {
    public static let shared = AIAccountSignInWindowController()

    private var window: NSWindow?
    private weak var aiUsageViewModel: AIUsageViewModel?

    private override init() {
        super.init()
    }

    public func presentSignIn(for provider: AIProviderType, viewModel: AIUsageViewModel) {
        self.aiUsageViewModel = viewModel
        viewModel.selectedProvider = provider
        viewModel.signInSelectedProvider = provider

        if let existing = window {
            existing.contentView = NSHostingView(
                rootView: AIAccountSignInModalView(
                    viewModel: viewModel,
                    onClose: { [weak self] in
                        self?.window?.close()
                    }
                )
            )
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "NotchHub — Connect & Sync AI Accounts"
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.contentView = NSHostingView(
            rootView: AIAccountSignInModalView(
                viewModel: viewModel,
                onClose: { [weak self] in
                    self?.window?.close()
                }
            )
        )
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AIAccountSignInModalView: View {
    @ObservedObject var viewModel: AIUsageViewModel
    let onClose: () -> Void

    var body: some View {
        let activeProvider = viewModel.signInSelectedProvider

        VStack(spacing: 0) {
            // Header Provider Selector
            HStack(spacing: 8) {
                ForEach(AIProviderType.allCases) { provider in
                    Button(action: {
                        viewModel.signInSelectedProvider = provider
                        viewModel.signInTokenInput = viewModel.customToken(for: provider) ?? ""
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: provider.symbolName)
                            Text(provider.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(activeProvider == provider ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(activeProvider == provider ? Color.accentColor : Color.secondary.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Done & Sync") {
                    Task {
                        await viewModel.refreshLiveStatuses()
                        onClose()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Action Bar: CLI Login + Token Input
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: {
                        viewModel.launchTerminalCLILogin(for: activeProvider)
                        viewModel.signInStatusBanner = "Launched `\(activeProvider.cliLoginCommand)` in Terminal. Click 'Done & Sync' once finished."
                    }) {
                        Label("Run `\(activeProvider.cliLoginCommand)` in Terminal", systemImage: "terminal.fill")
                    }

                    Spacer()

                    TextField("Optional: Paste \(activeProvider.rawValue) OAuth or API Token...", text: $viewModel.signInTokenInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)

                    Button("Save Token & Sync") {
                        viewModel.saveCustomToken(viewModel.signInTokenInput, for: activeProvider)
                        viewModel.signInStatusBanner = "Saved token and synced \(activeProvider.rawValue) account!"
                    }
                }

                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.signInStatusBanner)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Mark Web Session Connected & Sync") {
                        viewModel.markWebSessionConnected(for: activeProvider)
                        viewModel.signInStatusBanner = "Connected \(activeProvider.rawValue) web session and synced usage!"
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Embedded WKWebView for direct provider sign-in
            ProviderWebView(
                url: activeProvider.signInURL,
                provider: activeProvider,
                onDetectedSessionCookie: {
                    viewModel.markWebSessionConnected(for: activeProvider)
                    viewModel.signInStatusBanner = "Detected active \(activeProvider.rawValue) web session cookie — Usage synced!"
                }
            )
        }
    }
}

private struct ProviderWebView: NSViewRepresentable {
    let url: URL
    let provider: AIProviderType
    let onDetectedSessionCookie: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(provider: provider, onDetectedSessionCookie: onDetectedSessionCookie)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentProvider != provider {
            context.coordinator.currentProvider = provider
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var currentProvider: AIProviderType
        let onDetectedSessionCookie: () -> Void

        init(provider: AIProviderType, onDetectedSessionCookie: @escaping () -> Void) {
            self.currentProvider = provider
            self.onDetectedSessionCookie = onDetectedSessionCookie
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            let provider = currentProvider
            let callback = onDetectedSessionCookie
            cookieStore.getAllCookies { cookies in
                let matched = cookies.contains { cookie in
                    switch provider {
                    case .claude:
                        return cookie.domain.contains("claude.ai") && (cookie.name.contains("sessionKey") || cookie.name.contains("lastActiveOrg"))
                    case .chatgpt:
                        return cookie.domain.contains("chatgpt.com") && cookie.name.contains("session-token")
                    case .gemini:
                        return cookie.domain.contains("google.com") && cookie.name == "SID"
                    case .opencode:
                        return cookie.domain.contains("opencode.ai")
                    case .ollama:
                        return false
                    }
                }
                if matched {
                    Task { @MainActor in
                        callback()
                    }
                }
            }
        }
    }
}
