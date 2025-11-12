//
//  CameraView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import AVFoundation
import CoreLocation

struct CameraView: View {
    let claim: Claim
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var cameraModel = CameraViewModel()
    
    @State private var showingPhotoReview = false
    @State private var capturedImage: UIImage?
    @State private var damageType: String = "General"
    @State private var showingDamageTypePicker = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var zoomLevel: CGFloat = 1.0
    @State private var showingGrid = true
    
    private let damageTypes = [
        "General", "Roof", "Siding", "Windows", "Doors",
        "Interior", "Water Damage", "Foundation", "Other"
    ]
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(cameraModel: cameraModel)
                .ignoresSafeArea()
                .onAppear {
                    cameraModel.startSession()
                }
                .onDisappear {
                    cameraModel.stopSession()
                }
            
            // Grid Overlay
            if showingGrid {
                GridOverlay()
                    .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack {
                // Top Bar
                topBar
                
                Spacer()
                
                // Info Bar
                infoBar
                
                // Capture Controls
                captureControls
                    .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPhotoReview) {
            if let image = capturedImage {
                PhotoReviewView(
                    image: image,
                    claim: claim,
                    damageType: damageType,
                    metadata: createPhotoMetadata()
                )
            }
        }
        .actionSheet(isPresented: $showingDamageTypePicker) {
            ActionSheet(
                title: Text("Select Damage Type"),
                buttons: damageTypes.map { type in
                    .default(Text(type)) {
                        damageType = type
                    }
                } + [.cancel()]
            )
        }
    }
    
    // MARK: - View Components
    
    private var topBar: some View {
        HStack {
            // Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Flash Mode
            Menu {
                Button(action: { flashMode = .auto }) {
                    Label("Auto", systemImage: flashMode == .auto ? "checkmark" : "")
                }
                Button(action: { flashMode = .on }) {
                    Label("On", systemImage: flashMode == .on ? "checkmark" : "")
                }
                Button(action: { flashMode = .off }) {
                    Label("Off", systemImage: flashMode == .off ? "checkmark" : "")
                }
            } label: {
                Image(systemName: flashIcon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            // Grid Toggle
            Button(action: { showingGrid.toggle() }) {
                Image(systemName: showingGrid ? "grid" : "grid.slash")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var infoBar: some View {
        VStack(spacing: 8) {
            // Claim Info
            HStack {
                Text(claim.claimNumber)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("•")
                
                Text(claim.insuredName)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            
            // Damage Type Selector
            Button(action: { showingDamageTypePicker = true }) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                    
                    Text(damageType)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(20)
            }
        }
        .padding(.bottom, 10)
    }
    
    private var captureControls: some View {
        HStack(spacing: 50) {
            // Photo Library
            Button(action: {}) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                    )
            }
            
            // Capture Button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                }
            }
            
            // Switch Camera
            Button(action: { cameraModel.switchCamera() }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
            }
        }
    }
    
    private var flashIcon: String {
        switch flashMode {
        case .auto:
            return "bolt.badge.automatic"
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash.fill"
        @unknown default:
            return "bolt.badge.automatic"
        }
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        cameraModel.capturePhoto { image in
            if let image = image {
                self.capturedImage = image
                self.showingPhotoReview = true
            }
        }
    }
    
    private func createPhotoMetadata() -> PhotoMetadata {
        let deviceInfo = DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        let cameraSettings = CameraSettings(
            flashUsed: flashMode == .on,
            zoomLevel: Double(zoomLevel),
            orientation: UIDevice.current.orientation.isLandscape ? "landscape" : "portrait"
        )
        
        return PhotoMetadata(
            captureDate: Date(),
            location: locationManager.createLocationMetadata(),
            deviceInfo: deviceInfo,
            weather: nil, // Would fetch from weather API
            cameraSettings: cameraSettings
        )
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let cameraModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        cameraModel.previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraModel.previewLayer)
        
        DispatchQueue.main.async {
            cameraModel.previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        cameraModel.previewLayer.frame = uiView.bounds
    }
}

// MARK: - Camera View Model

class CameraViewModel: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    private var photoOutput = AVCapturePhotoOutput()
    private var currentCamera: AVCaptureDevice?
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            return
        }
        
        currentCamera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
            }
        } catch {
            print("Failed to setup camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func switchCamera() {
        captureSession.beginConfiguration()
        
        // Remove current input
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        // Get new camera
        let newPosition: AVCaptureDevice.Position = currentCamera?.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        // Add new input
        do {
            let input = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentCamera = newCamera
            }
        } catch {
            print("Failed to switch camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        if let camera = currentCamera, camera.hasFlash {
            settings.flashMode = .auto
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletion?(nil)
            return
        }
        
        photoCaptureCompletion?(image)
    }
}

// MARK: - Grid Overlay

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                
                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                
                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
    }
}

#Preview {
    CameraView(
        claim: Claim(
            claimNumber: "CLM-2024-001",
            insuredName: "John Doe",
            address: "123 Main St"
        )
    )
    .environmentObject(LocationManager.shared)
}
