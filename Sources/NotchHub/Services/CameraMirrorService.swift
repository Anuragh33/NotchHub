@preconcurrency import AVFoundation
import AppKit
import Combine
import SwiftUI

@MainActor
public final class CameraMirrorService: NSObject, ObservableObject {
    public static let shared = CameraMirrorService()

    @Published public private(set) var isSessionRunning: Bool = false
    @Published public private(set) var hasCameraPermission: Bool = false
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public var isMirrored: Bool = true

    public let captureSession = AVCaptureSession()

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: AnyCancellable?

    public override init() {
        super.init()
        checkPermission()
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.hasCameraPermission = granted
                }
            }
        default:
            hasCameraPermission = false
        }
    }

    public func startSession() {
        guard hasCameraPermission else {
            checkPermission()
            return
        }
        guard !captureSession.isRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }

        if let camera = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: camera),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        captureSession.commitConfiguration()

        let session = captureSession
        Task.detached {
            session.startRunning()
            await MainActor.run {
                CameraMirrorService.shared.isSessionRunning = session.isRunning
                CameraMirrorService.shared.startAudioMetering()
            }
        }
    }

    public func stopSession() {
        stopAudioMetering()
        guard captureSession.isRunning else { return }
        let session = captureSession
        Task.detached {
            session.stopRunning()
            await MainActor.run {
                CameraMirrorService.shared.isSessionRunning = false
            }
        }
    }

    private func startAudioMetering() {
        let tempURL = URL(fileURLWithPath: "/dev/null")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        audioRecorder = try? AVAudioRecorder(url: tempURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        levelTimer = Timer.publish(every: 0.08, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let avg = recorder.averagePower(forChannel: 0)
                let normalized = max(0.0, (avg + 50.0) / 50.0)
                self.audioLevel = normalized
            }
    }

    private func stopAudioMetering() {
        levelTimer?.cancel()
        levelTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        audioLevel = 0.0
    }
}

public struct CameraPreviewViewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    public init(session: AVCaptureSession, isMirrored: Bool) {
        self.session = session
        self.isMirrored = isMirrored
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        if previewLayer.connection?.isVideoMirroringSupported == true {
            previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
            previewLayer.connection?.isVideoMirrored = isMirrored
        }
        view.layer?.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        context.coordinator.previewLayer?.frame = nsView.bounds
        if let conn = context.coordinator.previewLayer?.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = isMirrored
        }
        CATransaction.commit()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
