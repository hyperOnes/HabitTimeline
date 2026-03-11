import Foundation
import ScreenCaptureKit
import AVFoundation
import Accelerate
import Combine

/// Manages system audio capture and beat detection for visualizations
@MainActor
final class AudioCaptureManager: NSObject, ObservableObject {
    static let shared = AudioCaptureManager()

    @Published var isCapturing = false
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 10)
    @Published var beatIntensity: Float = 0
    @Published var isBeat: Bool = false

    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private var analysisTimer: Timer?

    // Audio analysis
    private var recentSamples: [Float] = []
    private let sampleHistorySize = 44100 // ~1 second at 44.1kHz
    private var beatThreshold: Float = 0.6
    private var lastBeatTime: Date = .distantPast
    private let minBeatInterval: TimeInterval = 0.1 // Max 10 beats per second

    // Frequency bands for visualization (bass to treble)
    private let bandCount = 10

    private override init() {
        super.init()
    }

    func startCapturing() async {
        guard !isCapturing else { return }

        do {
            // Request permission
            guard try await SCShareableContent.current.displays.first != nil else {
                print("No display available")
                return
            }

            // Get shareable content
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

            guard let display = content.displays.first else {
                print("No display found")
                return
            }

            // Create filter for audio-only capture
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Configure stream for audio only
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            config.channelCount = 2
            config.sampleRate = 44100
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // Minimal video
            config.showsCursor = false

            // Create stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            self.stream = stream

            // Create and add output
            let output = AudioStreamOutput { [weak self] samples in
                Task { @MainActor in
                    self?.processAudioSamples(samples)
                }
            }
            self.streamOutput = output

            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))

            // Start capture
            try await stream.startCapture()
            isCapturing = true

            print("Audio capture started")
        } catch {
            print("Failed to start audio capture: \(error)")
        }
    }

    func stopCapturing() async {
        guard isCapturing else { return }

        do {
            try await stream?.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }

        stream = nil
        streamOutput = nil
        isCapturing = false
        audioLevels = Array(repeating: 0, count: bandCount)
        beatIntensity = 0
        isBeat = false

        print("Audio capture stopped")
    }

    func toggleCapturing() async {
        if isCapturing {
            await stopCapturing()
        } else {
            await startCapturing()
        }
    }

    private func processAudioSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        // Add to history
        recentSamples.append(contentsOf: samples)
        if recentSamples.count > sampleHistorySize {
            recentSamples.removeFirst(recentSamples.count - sampleHistorySize)
        }

        // Perform FFT analysis
        let fftResult = performFFT(samples)

        // Update audio levels for each band
        updateAudioLevels(from: fftResult)

        // Detect beats
        detectBeat(samples: samples)
    }

    private func performFFT(_ samples: [Float]) -> [Float] {
        let frameCount = samples.count
        guard frameCount > 0 else { return Array(repeating: 0, count: bandCount) }

        // Pad to power of 2
        let log2n = vDSP_Length(ceil(log2(Float(frameCount))))
        let fftSize = Int(1 << log2n)
        let halfSize = fftSize / 2

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0, count: bandCount)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Prepare input
        var paddedSamples = samples
        if paddedSamples.count < fftSize {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedSamples.count))
        }

        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(paddedSamples, 1, window, 1, &paddedSamples, 1, vDSP_Length(fftSize))

        // Split complex - use withUnsafeMutableBufferPointer for proper pointer lifetime
        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                paddedSamples.withUnsafeBufferPointer { ptr in
                    ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }
                }

                // FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Magnitude
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Scale
        var scale = Float(1.0 / Float(fftSize))
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))

        // Square root for actual magnitude
        var sqrtMagnitudes = [Float](repeating: 0, count: halfSize)
        vvsqrtf(&sqrtMagnitudes, magnitudes, [Int32(halfSize)])

        return sqrtMagnitudes
    }

    private func updateAudioLevels(from fftResult: [Float]) {
        guard !fftResult.isEmpty else { return }

        let binCount = fftResult.count
        var newLevels = [Float](repeating: 0, count: bandCount)

        // Logarithmic band distribution (more resolution in bass)
        let bandEdges = [0, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]

        for band in 0..<bandCount {
            let startBin = min(bandEdges[band], binCount - 1)
            let endBin = min(bandEdges[band + 1], binCount)

            if startBin < endBin {
                var sum: Float = 0
                vDSP_sve(Array(fftResult[startBin..<endBin]), 1, &sum, vDSP_Length(endBin - startBin))
                let avg = sum / Float(endBin - startBin)

                // Apply logarithmic scaling and boost
                let scaled = log10(1 + avg * 100) / 2.0
                newLevels[band] = min(scaled * 2.5, 1.0) // Boost and clamp
            }
        }

        // Smooth transition
        for i in 0..<bandCount {
            audioLevels[i] = audioLevels[i] * 0.3 + newLevels[i] * 0.7
        }
    }

    private func detectBeat(samples: [Float]) {
        // Calculate RMS energy
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Update beat intensity with smoothing
        let newIntensity = min(rms * 15, 1.0)
        beatIntensity = beatIntensity * 0.5 + newIntensity * 0.5

        // Simple beat detection: energy spike above threshold
        let now = Date()
        if beatIntensity > beatThreshold && now.timeIntervalSince(lastBeatTime) > minBeatInterval {
            isBeat = true
            lastBeatTime = now

            // Reset beat flag after short delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                self.isBeat = false
            }
        }
    }
}

// MARK: - Audio Stream Output Handler

private class AudioStreamOutput: NSObject, SCStreamOutput {
    private let handler: ([Float]) -> Void

    init(handler: @escaping ([Float]) -> Void) {
        self.handler = handler
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio samples from buffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let data = dataPointer else { return }

        // Convert to Float samples (assuming 32-bit float PCM)
        let floatCount = length / MemoryLayout<Float>.size
        let floatPointer = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: floatCount)
        let samples = Array(UnsafeBufferPointer(start: floatPointer, count: floatCount))

        handler(samples)
    }
}
