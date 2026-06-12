//
//  HeartRateEngine.swift
//  PulseGuard
//
//  Created by Hemant Khanna on 6/12/26.
//

import Foundation
import AVFoundation
import CoreImage
import SwiftUI
import Combine

class HeartRateEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var bpm: Int = 0
    @Published var isFingerDetected = false
    @Published var signalQuality: String = "No Signal"
    @Published var pulseValues: [Double] = [] // For live waveform chart
    
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private let processingQueue = DispatchQueue(label: "com.pulseguard.processing", qos: .userInteractive)
    
    // Signal Processing Variables
    private let bufferLimit = 150
    private var rawGreenValues: [Double] = []
    private var timestamps: [Double] = []
    private var lastBeatTime: Double = 0
    private var hrHistory: [Double] = []
    
    func startScanning() {
        requestCameraAccess { [weak self] granted in
            guard let self = self, granted else { return }
            self.setupCaptureSession()
        }
    }
    
    func stopScanning() {
        toggleTorch(on: false)
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { completion($0) }
        default:
            completion(false)
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .low // Lower resolution is optimal for pixel-average biosensing
        
        // Use rear wide-angle camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        self.videoDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: processingQueue)
            
            // Output 32BGRA format for reliable color channel extraction
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            
            if session.canAddOutput(output) { session.addOutput(output) }
            
            // Apply Camera locks to prevent the ISP from auto-compensating color changes
            try device.lockForConfiguration()
            
            // Set Frame Rate (Fixed 30 FPS)
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            
            // Lock Exposure and White Balance
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
            
            device.unlockForConfiguration()
            
            self.captureSession = session
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                self.toggleTorch(on: true)
            }
        } catch {
            print("Failed to lock configuration: \(error)")
        }
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be toggled")
        }
    }
    
    // Called for each camera frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var totalRed: Double = 0
        var totalGreen: Double = 0
        let totalPixels = Double(width * height)
        
        // Calculate raw color averages
        for row in 0..<height {
            let rowOffset = row * bytesPerRow
            for col in 0..<width {
                let pixelOffset = rowOffset + col * 4
                //let blue = Double(buffer[pixelOffset])
                let green = Double(buffer[pixelOffset + 1])
                let red = Double(buffer[pixelOffset + 2])
                
                totalRed += red
                totalGreen += green
            }
        }
        
        let avgRed = totalRed / totalPixels
        let avgGreen = totalGreen / totalPixels
        
        // Evaluate finger coverage threshold (Skin under intense red LED back-illumination)
        let isCovered = avgRed > 120.0 && avgGreen < 110.0
        
        DispatchQueue.main.async {
            self.isFingerDetected = isCovered
            if !isCovered {
                self.signalQuality = "Align Finger"
                self.rawGreenValues.removeAll()
                self.pulseValues.removeAll()
                self.bpm = 0
                return
            }
            
            self.signalQuality = "Signal Locked"
            self.processSignal(greenValue: avgGreen)
        }
    }
    
    private func processSignal(greenValue: Double) {
        let now = CACurrentMediaTime()
        rawGreenValues.append(greenValue)
        timestamps.append(now)
        
        if rawGreenValues.count > bufferLimit {
            rawGreenValues.removeFirst()
            timestamps.removeFirst()
        }
        
        guard rawGreenValues.count > 30 else { return }
        
        // Demean & Filter baseline wander (breathing & mechanical drift)
        let filteredSignal = applyHighPassFilter(input: rawGreenValues)
        
        // Push filtered value to SwiftUI graph array
        self.pulseValues = filteredSignal.suffix(50)
        
        // Peak and Heartbeat Rate detection
        detectPeaks(signal: filteredSignal, times: timestamps)
    }
    
    private func applyHighPassFilter(input: [Double]) -> [Double] {
        let windowSize = 15
        var filtered: [Double] = []
        for i in 0..<input.count {
            let start = max(0, i - windowSize)
            let end = min(input.count - 1, i + windowSize)
            var sum = 0.0
            for j in start...end { sum += input[j] }
            let mean = sum / Double(end - start + 1)
            filtered.append(input[i] - mean)
        }
        return filtered
    }
    
    private func detectPeaks(signal: [Double], times: [Double]) {
        let threshold = 0.5
        let coolDown = 0.3 // 300ms lock (Max 200 BPM)
        //let now = CACurrentMediaTime()
        
        for i in 1..<(signal.count - 1) {
            let val = signal[i]
            if val > signal[i-1] && val > signal[i+1] && val > threshold {
                let timestamp = times[i]
                if timestamp - lastBeatTime > coolDown {
                    let interval = timestamp - lastBeatTime
                    lastBeatTime = timestamp
                    
                    let instantBpm = 60.0 / interval
                    if instantBpm >= 45 && instantBpm <= 180 {
                        hrHistory.append(instantBpm)
                        if hrHistory.count > 8 { hrHistory.removeFirst() }
                        
                        // Emit smoothed beat
                        let averageBpm = hrHistory.reduce(0, +) / Double(hrHistory.count)
                        self.bpm = Int(round(averageBpm))
                        triggerFeedback()
                    }
                }
            }
        }
    }
    
    private func triggerFeedback() {
        // Trigger delicate custom vibration on each beat
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
