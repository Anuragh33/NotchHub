import SwiftUI

public struct ExpandedNotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let notchGeo = viewModel.geometryManager.currentGeometry

        VStack(spacing: 6) {
            // Top bar flanking the physical camera housing on either side
            HStack(spacing: 0) {
                // Left wing: Left tabs (Home, Media, AI, Timer)
                HStack(spacing: 6) {
                    ForEach(NotchTab.leftTabs) { tab in
                        tabPillButton(for: tab)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)

                // Center gap reserved for physical camera housing
                Color.clear
                    .frame(width: notchGeo.notchSize.width, height: max(32.0, notchGeo.notchSize.height))

                // Right wing: Right tabs (Shelf, Clipboard, Apps, Mirror)
                HStack(spacing: 6) {
                    ForEach(NotchTab.rightTabs) { tab in
                        tabPillButton(for: tab)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
            }
            .frame(height: max(32.0, notchGeo.notchSize.height))

            // Main Modular Widget Content Area
            Group {
                switch viewModel.selectedTab {
                case .home:
                    BentoHomeView(notchViewModel: viewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .media:
                    NowPlayingView()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .aiUsage:
                    AIUsageView(viewModel: viewModel.aiUsageViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .timer:
                    PomodoroTimerView(viewModel: viewModel.utilitiesViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .shelf:
                    FileShelfView(viewModel: viewModel.shelfViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .clipboard:
                    ClipboardShelfView(viewModel: viewModel.clipboardViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .apps:
                    AppLauncherView(
                        viewModel: viewModel.appLauncherViewModel,
                        onLaunched: { viewModel.collapseImmediately() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .mirror:
                    CameraMirrorView()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .palette:
                    CommandPaletteView(viewModel: viewModel.commandPaletteViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.1))
                .padding(.horizontal, 18)

            // Bottom Quick Utilities Strip (Pomodoro Pill, Scratchpad, ⌃⌥K Command Palette Button, and Settings Menu)
            QuickUtilitiesBar(
                utilitiesViewModel: viewModel.utilitiesViewModel,
                notchViewModel: viewModel
            )
        }
    }

    @ViewBuilder
    private func tabPillButton(for tab: NotchTab) -> some View {
        Button(action: {
            withAnimation(NotchViewModel.springAnimation) {
                viewModel.selectTab(tab)
            }
        }) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(viewModel.selectedTab == tab ? Color.black : Color.white.opacity(0.80))
                .frame(width: 27, height: 23)
                .background(
                    Capsule(style: .continuous)
                        .fill(viewModel.selectedTab == tab ? Color.white : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }
}
