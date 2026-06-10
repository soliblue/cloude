import AVFoundation
import UIKit

final class OnboardingViewScannerSheetController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Bool)?
    var onPermissionDenied: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let haptics = UINotificationFeedbackGenerator()
    private var hasEmitted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        haptics.prepare()
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            configure()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configure()
                        self?.startSession()
                    } else {
                        self?.onPermissionDenied?()
                    }
                }
            }
        } else {
            onPermissionDenied?()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func startSession() {
        if !session.inputs.isEmpty, !session.isRunning {
            hasEmitted = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    private func configure() {
        if let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        {
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                if output.availableMetadataObjectTypes.contains(.qr) {
                    output.metadataObjectTypes = [.qr]
                }
            }
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)
            previewLayer = preview
        }
    }

    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        if !hasEmitted,
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue
        {
            hasEmitted = true
            let accepted = onCode?(value) ?? false
            haptics.notificationOccurred(accepted ? .success : .error)
            if !accepted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.hasEmitted = false
                }
            }
        }
    }
}
