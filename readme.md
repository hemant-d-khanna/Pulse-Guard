# PulseGuard - iOS Heart Rate Monitor

This application has been created using Gemini AI. PulseGuard is a native iOS application designed to measure your heart rate in real-time using Photoplethysmography (PPG). By utilizing the iPhone's rear camera and LED flash, the app detects arterial blood flow, calculates your heart rate (BPM), and provides immediate haptic feedback.

## Features

- **Real-time PPG Biosensing:** High-speed frame extraction and green-channel pixel analysis.
- **Pulse Wave Visualization:** Live chart display of your cardiac signal.
- **Smart Filtering:** Integrated high-pass filter to remove motion artifacts and breathing interference.
- **Haptic Feedback:** Tactile pulses synchronized with your detected heart rate.
- **Privacy-First:** Operates entirely on-device; no data is transmitted.

## Prerequisites

- **Mac** running macOS with **Xcode** installed.
- Physical **iPhone** (iOS 15 or later).
- USB-to-Lightning or USB-C cable to connect your iPhone to your Mac.
- A free **Apple ID**.

## Installation & Deployment

Follow these steps to build and install PulseGuard directly from Xcode onto your iPhone.

### Step 1: Create the Project
1. Open **Xcode** > **Create New Project** > **App** (iOS).
2. Set **Product Name** to `PulseGuard`.
3. Choose `SwiftUI` for the Interface and `Swift` for the Language.

### Step 2: Add the Source Code
1. Replace the contents of `ContentView.swift` with the main SwiftUI view code.
2. Create a new file in your project: **File** > **New** > **File** > **Swift File**, and name it `HeartRateEngine.swift`.
3. Paste the core Heart Rate Engine logic into this file.

### Step 3: Permissions & Signing
1. **Camera Permissions:** Select the `PulseGuard` project node > **Info** tab. Add `Privacy - Camera Usage Description` with the value: `This app uses the rear camera and flash to measure your heart rate through your finger.`
2. **Code Signing:** Select the `PulseGuard` project node > **Signing & Capabilities**. Check **Automatically manage signing** and select your Apple ID from the **Team** dropdown.

### Step 4: Run on iPhone
1. Connect your iPhone to your Mac.
2. Select your iPhone from the destination scheme menu in Xcode.
3. Click the **Run** (Play) button.

### Step 5: Authorization
1. On your iPhone: **Settings** > **General** > **VPN & Device Management**.
2. Tap your Apple ID profile and select **Trust**.
3. If on iOS 16+: **Settings** > **Privacy & Security** > **Developer Mode** > **On** (requires restart).
