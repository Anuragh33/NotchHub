import AVFoundation
import AppKit
import SwiftUI

public struct CameraMirrorView: View {
    @ObservedObject var cameraService: CameraMirrorService = .shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            if cameraService.hasCameraPermission {
                activeCameraContent
            } else {
                permissionPromptContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            cameraService.startSession()
        }
    }

    private var activeCameraContent: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                CameraPreviewViewRepresentable(
                    session: cameraService.captureSession,
                    isMirrored: cameraService.isMirrored
                )
                .frame(width: 320, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)

                // Controls and Mic HUD Overlay
                HStack(spacing: 12) {
                    // Live Camera Dot
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .shadow(color: .green.opacity(0.8), radius: 3)

                        Text("HD Mirror")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())

                    Spacer()

                    // Live Mic VU Meter
                    HStack(spacing: 3) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))

                        ForEach(0..<5, id: \.self) { idx in
                            let threshold = Float(idx + 1) * 0.18
                            Capsule()
                                .fill(cameraService.audioLevel >= threshold ? Color.green : Color.white.opacity(0.2))
                                .frame(width: 3, height: 8)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())

                    // Mirror Toggle Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cameraService.isMirrored.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Flip Mirror")
                }
                .padding(8)
            }

            Text("Camera check before calls • Auto-shuts down when hidden")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var permissionPromptContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 32))
                .foregroundColor(.yellow.opacity(0.9))

            Text("Camera Access Required")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("NotchHub uses the MacBook camera solely for this instant mirror preview.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                cameraService.checkPermission()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open Settings & Allow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}
