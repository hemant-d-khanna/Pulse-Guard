//
//  ContentView.swift
//  PulseGuard
//
//  Created by Hemant Khanna on 6/12/26.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var hrEngine = HeartRateEngine()
    @State private var isScanning = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("PulseGuard")
                .font(.title)
                .fontWeight(.bold)
            
            // Circular Pulse Indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 200, height: 200)
                
                VStack {
                    Text("HEART RATE")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(hrEngine.bpm > 0 ? "\(hrEngine.bpm)" : "--")
                        .font(.system(size: 64, weight: .black))
                    Text("BPM")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.red)
                }
                
                // Pulsing indicator ring
                Circle()
                    .stroke(Color.red.opacity(hrEngine.bpm > 0 ? 0.6 : 0), lineWidth: 4)
                    .scaleEffect(hrEngine.bpm > 0 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1).repeatCount(1, autoreverses: true), value: hrEngine.bpm)
            }
            .frame(width: 220, height: 220)
            
            // Pulse waveform chart
            VStack(alignment: .leading) {
                Text("LIVE PPG SIGNAL")
                    .font(.caption)
                    .bold()
                Chart {
                    ForEach(Array(hrEngine.pulseValues.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Intensity", value)
                        )
                        .foregroundStyle(Color.red)
                    }
                }
                .chartYScale(domain: -10...10) // Adapt based on filtered scale bounds
                .frame(height: 100)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // Status and Actions
            Text(hrEngine.signalQuality)
                .font(.footnote)
                .foregroundColor(hrEngine.isFingerDetected ? .green : .orange)
            
            Button(action: {
                isScanning.toggle()
                if isScanning {
                    hrEngine.startScanning()
                } else {
                    hrEngine.stopScanning()
                }
            }) {
                Text(isScanning ? "Stop Session" : "Start Pulse Scan")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isScanning ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
