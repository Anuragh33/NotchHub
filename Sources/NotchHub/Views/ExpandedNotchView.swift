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
                // Left of camera housing: Tab Switcher
                HStack(spacing: 6) {
                    ForEach(NotchTab.allCases) { tab in
                        Button(action: {
                            withAnimation(NotchViewModel.springAnimation) {
                                viewModel.selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.symbolName)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(viewModel.selectedTab == tab ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(viewModel.selectedTab == tab ? Color.white : Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 18)

                // Center gap reserved for physical camera housing
                Spacer(minLength: notchGeo.notchSize.width)

                // Right of camera housing: Compact Wings toggle badge & Shelf badge
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.toggleCompactWingsMode()
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isCompactWingsEnabled ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(viewModel.isCompactWingsEnabled ? "Wings On" : "Wings Off")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
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
                .padding(.trailing, 18)
            }
            .frame(height: max(32.0, notchGeo.notchSize.height))

            // Main Modular Widget Content Area
            Group {
                switch viewModel.selectedTab {
                case .media:
                    MediaControllerView(viewModel: viewModel.mediaViewModel)
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
