import SwiftUI

public struct ExpandedNotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let notchGeo = viewModel.geometryManager.currentGeometry

        VStack(spacing: 6) {
            // Top bar flanking the physical camera housing
            HStack(spacing: 0) {
                // Left of camera housing: Tab Switcher (Media, AI Usage, Drop Shelf)
                HStack(spacing: 5) {
                    ForEach(NotchTab.allCases) { tab in
                        Button(action: {
                            withAnimation(NotchViewModel.springAnimation) {
                                viewModel.selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.symbolName)
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(viewModel.selectedTab == tab ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(viewModel.selectedTab == tab ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 16)

                // Center gap reserved for physical camera housing
                Spacer(minLength: notchGeo.notchSize.width)

                // Right of camera housing: Menu Bar Icon Toggle & Compact Wings Toggle
                HStack(spacing: 6) {
                    Button(action: {
                        viewModel.toggleMenuBarIcon()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isMenuBarIconEnabled ? "menubar.rectangle" : "menubar.arrow.up.rectangle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(viewModel.isMenuBarIconEnabled ? Color.cyan : Color.gray)
                            Text(viewModel.isMenuBarIconEnabled ? "Menu Icon On" : "Menu Icon Off")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle NotchHub Icon in macOS Menu Bar")

                    Button(action: {
                        viewModel.toggleCompactWingsMode()
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isCompactWingsEnabled ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(viewModel.isCompactWingsEnabled ? "Wings On" : "Wings Off")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
            }
            .frame(height: max(32.0, notchGeo.notchSize.height))

            // Main Modular Widget Content Area
            Group {
                switch viewModel.selectedTab {
                case .media:
                    MediaControllerView(viewModel: viewModel.mediaViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .aiUsage:
                    AIUsageView(viewModel: viewModel.aiUsageViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                case .shelf:
                    FileShelfView(viewModel: viewModel.shelfViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.1))
                .padding(.horizontal, 18)

            // Bottom Quick Utilities Strip
            QuickUtilitiesBar(
                utilitiesViewModel: viewModel.utilitiesViewModel,
                notchViewModel: viewModel
            )
        }
    }
}
