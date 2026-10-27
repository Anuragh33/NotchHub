import SwiftUI

public struct NotchContainerView: View {
    @ObservedObject var viewModel: NotchViewModel

    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let size = viewModel.currentNotchSize()
        let topR = viewModel.topEarRadius
        let botR = viewModel.bottomCornerRadius
        let notchShape = NotchShape(topCornerRadius: topR, bottomCornerRadius: botR)
        let isHidden = viewModel.isHiddenWhenIdle

        ZStack(alignment: .top) {
            Color.clear

            ZStack(alignment: .top) {
                // Pure #000000 pitch-black notch body with top ear cutouts
                notchShape
                    .fill(Color(red: 0, green: 0, blue: 0))
                    .overlay(
                        notchShape
                            .stroke(
                                Color.white.opacity((viewModel.expansionState == .collapsed || isHidden) ? 0.0 : 0.11),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(
                        color: viewModel.expansionState == .expanded ? Color.black.opacity(0.55) : Color.clear,
                        radius: viewModel.expansionState == .expanded ? 22 : 0,
                        x: 0,
                        y: viewModel.expansionState == .expanded ? 10 : 0
                    )

                // State-specific inner content padded inside top ear overhang
                Group {
                    switch viewModel.expansionState {
                    case .collapsed:
                        EmptyView()

                    case .compactWings:
                        CompactWingsView(
                            aiUsageViewModel: viewModel.aiUsageViewModel,
                            utilitiesViewModel: viewModel.utilitiesViewModel,
                            hardwareNotchWidth: viewModel.geometryManager.currentGeometry.notchSize.width
                        )
                        .padding(.horizontal, topR)
                        .transition(.opacity)

                    case .expanded:
                        ExpandedNotchView(viewModel: viewModel)
                            .padding(.horizontal, topR)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(notchShape)
            .contentShape(notchShape)
            .opacity(isHidden ? 0.0 : 1.0)
            .onHover { hovering in
                if hovering {
                    viewModel.handleMouseEnteredPanel()
                } else {
                    viewModel.handleMouseExitedPanel()
                }
            }
            .onTapGesture {
                if viewModel.expansionState != .expanded && viewModel.notchDisplayMode != .completelyOff {
                    viewModel.expandImmediately()
                }
            }
            .animation(NotchViewModel.springAnimation, value: viewModel.expansionState)
            .animation(NotchViewModel.springAnimation, value: viewModel.selectedTab)
            .animation(NotchViewModel.springAnimation, value: viewModel.notchDisplayMode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
