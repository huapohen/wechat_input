import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class SpeechCapture: ObservableObject {
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var error: String?
    @Published private(set) var authorization: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var timer: Timer?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private(set) var localeIdentifier = "zh-CN"

    var isAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    func requestAccess() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorization = speech
        guard speech == .authorized else {
            error = speechMessage(speech)
            return false
        }
        let mic = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard mic else {
            error = "麦克风权限未开启，请到系统设置中允许微输入法访问麦克风。"
            return false
        }
        return true
    }

    func start(locale: String = "zh-CN") throws {
        guard !isRecording else { return }
        error = nil
        localeIdentifier = locale
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let recognizer else {
            throw SpeechError.unavailable("无法创建 \(locale) 语音识别器")
        }
        guard recognizer.isAvailable else {
            throw SpeechError.unavailable("当前设备暂不可用 \(locale) 语音识别。模拟器可能不支持设备语音，请使用真机或检查网络。")
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechError.unauthorized("语音识别权限未开启，请先在本页授权。")
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition && SharedStore.bool(SharedKeys.voiceOffline) {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw SpeechError.unavailable("没有可用的音频输入设备")
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, recognitionError in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finalizeStop()
                    }
                }
                if let recognitionError, self.isRecording {
                    let message = recognitionError.localizedDescription
                    if !message.isEmpty {
                        self.error = "语音识别中断：\(message)"
                    }
                    self.finalizeStop()
                }
            }
        }

        isRecording = true
        isPaused = false
        startedAt = Date()
        startTimer()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        engine.pause()
        isPaused = true
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
        }
        startedAt = nil
        timer?.invalidate()
    }

    func resume() throws {
        guard isRecording, isPaused else { return }
        try engine.start()
        isPaused = false
        startedAt = Date()
        startTimer()
    }

    func stop() {
        guard isRecording else { return }
        finalizeStop()
    }

    private func finalizeStop() {
        guard isRecording else { return }
        isRecording = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
        }
        startedAt = nil
        elapsed = accumulated
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        if isRecording { stop() }
        transcript = ""
        elapsed = 0
        accumulated = 0
        error = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = self.accumulated + Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func speechMessage(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied: return "语音识别权限被拒绝，请到系统设置中开启。"
        case .restricted: return "当前设备限制了语音识别。"
        case .notDetermined: return "尚未授权语音识别。"
        case .authorized: return ""
        @unknown default: return "未知的语音识别授权状态。"
        }
    }
}

enum SpeechError: LocalizedError {
    case unavailable(String)
    case unauthorized(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .unauthorized(let message): return message
        }
    }
}
