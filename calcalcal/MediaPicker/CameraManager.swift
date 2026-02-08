import AVFoundation
import UIKit
import Combine

/// Manages AVFoundation camera session, photo capture, and flash control
class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isSessionRunning = false
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var capturedImage: UIImage?
    @Published var error: CameraError?
    
    // MARK: - Public Properties
    
    let session = AVCaptureSession()
    
    // MARK: - Private Properties
    
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.calycal.camera.session")
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    private var isConfigured = false
    
    // MARK: - Error Types
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case configurationFailed
        case captureError(String)
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera is not available on this device"
            case .permissionDenied:
                return "Camera permission was denied"
            case .configurationFailed:
                return "Failed to configure camera"
            case .captureError(let message):
                return "Capture error: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Handling
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.permissionStatus = status
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
                completion(granted)
            }
        }
    }
    
    // MARK: - Session Configuration and Start
    
    /// Configures and starts the camera session
    /// This method handles both configuration and starting in the correct order
    func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Configure if not already configured
            if !self.isConfigured {
                self.configureSession()
            }
            
            // Start if configured successfully and not already running
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    private func configureSession() {
        guard permissionStatus == .authorized else {
            DispatchQueue.main.async {
                self.error = .permissionDenied
            }
            return
        }
        
        // Check if already configured
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .photo
        
        // Add video input
        do {
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.error = .cameraUnavailable
                }
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                DispatchQueue.main.async {
                    self.error = .configurationFailed
                }
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .configurationFailed
            }
            return
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            DispatchQueue.main.async {
                self.error = .configurationFailed
            }
            return
        }
        
        // Mark as configured only after successful setup
        isConfigured = true
    }
    
    // MARK: - Session Control

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    /// Pause the session temporarily (e.g. when gallery is expanded)
    func pauseSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    /// Resume a previously paused session
    func resumeSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.photoCaptureCompletion = completion
        
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard self.isConfigured else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let settings = AVCapturePhotoSettings()
            
            // Configure flash if available
            if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            
            settings.isHighResolutionPhotoEnabled = true
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Flash Control
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
    
    var isFlashAvailable: Bool {
        guard let device = videoDeviceInput?.device else { return false }
        return device.hasFlash && device.isFlashAvailable
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.error = .captureError(error.localizedDescription)
                self?.photoCaptureCompletion?(nil)
                self?.photoCaptureCompletion = nil
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.error = .captureError("Failed to process photo data")
                self?.photoCaptureCompletion?(nil)
                self?.photoCaptureCompletion = nil
            }
            return
        }
        
        // Fix image orientation
        let correctedImage = fixImageOrientation(image)
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = correctedImage
            self?.photoCaptureCompletion?(correctedImage)
            self?.photoCaptureCompletion = nil
        }
    }
    
    /// Corrects image orientation to always be up
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
}
