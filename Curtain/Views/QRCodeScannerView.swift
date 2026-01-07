//
//  QRCodeScannerView.swift
//  Curtain
//
//  Created by Toan Phung on 02/08/2025.
//

import SwiftUI
import AVFoundation

// MARK: - QR Code Scanner View

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCodeScanned: (String) -> Void
    
    @State private var isCameraPermissionDenied = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                QRScannerRepresentable(
                    onCodeScanned: { code in
                        onCodeScanned(code)
                        dismiss()
                    },
                    onPermissionDenied: {
                        isCameraPermissionDenied = true
                        showingPermissionAlert = true
                    }
                )
                
                // Overlay UI
                VStack {
                    // Top instruction
                    VStack(spacing: 8) {
                        Text("Scan QR Code")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Position the QR code within the frame")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Scanning frame
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay(
                            // Corner indicators
                            ForEach(0..<4) { index in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: 20, height: 20)
                                    .position(cornerPosition(for: index))
                            }
                        )
                    
                    Spacer()
                    
                    // Bottom instructions
                    VStack(spacing: 12) {
                        Text("Supports Curtain session URLs and deep links")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button("Manual Entry") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
            .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Please enable camera access in Settings to scan QR codes.")
            }
        }
    }
    
    private func cornerPosition(for index: Int) -> CGPoint {
        let size: CGFloat = 250
        let offset: CGFloat = 10
        
        switch index {
        case 0: return CGPoint(x: offset, y: offset) // Top-left
        case 1: return CGPoint(x: size - offset, y: offset) // Top-right
        case 2: return CGPoint(x: offset, y: size - offset) // Bottom-left
        case 3: return CGPoint(x: size - offset, y: size - offset) // Bottom-right
        default: return CGPoint.zero
        }
    }
}

// MARK: - UIKit Camera Integration

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onPermissionDenied: () -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerRepresentable
        
        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            parent.onCodeScanned(code)
        }
        
        func didFailWithPermissionDenied() {
            parent.onPermissionDenied()
        }
    }
}

// MARK: - QR Scanner Controller

protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithPermissionDenied()
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func startScanning() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startScanning()
                    } else {
                        self.delegate?.didFailWithPermissionDenied()
                    }
                }
            }
        case .denied, .restricted:
            delegate?.didFailWithPermissionDenied()
        @unknown default:
            delegate?.didFailWithPermissionDenied()
        }
    }
    
    private func stopScanning() {
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

// MARK: - Metadata Output Delegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Haptic feedback
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // Stop scanning
            stopScanning()
            
            // Notify delegate
            delegate?.didScanCode(stringValue)
        }
    }
}

#Preview {
    QRCodeScannerView { code in
    }
}