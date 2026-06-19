import Flutter
import UIKit
import AVFoundation
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
  private let ttsChannelName = "smart_campus_guide/tts"
  private let locationChannelName = "smart_campus_guide/location"
  private let speechSynthesizer = AVSpeechSynthesizer()
  private let locationManager = CLLocationManager()
  private var ttsChannel: FlutterMethodChannel?
  private var locationChannel: FlutterMethodChannel?
  private var pendingLocationResult: FlutterResult?
  private var didLogSpeechVoices = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupTtsChannel(messenger: controller.binaryMessenger)
      setupLocationChannel(messenger: controller.binaryMessenger)
    }
    speechSynthesizer.delegate = self
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupTtsChannel(messenger: engineBridge.applicationRegistrar.messenger())
    setupLocationChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func setupTtsChannel(messenger: FlutterBinaryMessenger) {
    guard ttsChannel == nil else { return }
    let channel = FlutterMethodChannel(name: ttsChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(["ok": false, "reason": "TTS service released"])
        return
      }
      switch call.method {
      case "speak":
        let args = call.arguments as? [String: Any]
        let text = args?["text"] as? String ?? ""
        let voice = args?["voice"] as? String ?? ""
        let language = args?["language"] as? String ?? "zh"
        let rate = (args?["rate"] as? NSNumber)?.doubleValue ?? 1.0
        result(self.speak(text: text, voice: voice, language: language, rate: rate))
      case "stop":
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        result(["ok": true])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    ttsChannel = channel
  }

  private func setupLocationChannel(messenger: FlutterBinaryMessenger) {
    guard locationChannel == nil else { return }
    let channel = FlutterMethodChannel(name: locationChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(["ok": false, "reason": "Location service released"])
        return
      }
      switch call.method {
      case "getCurrentLocation":
        self.getCurrentLocation(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    locationChannel = channel
  }

  private func getCurrentLocation(result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result(["ok": false, "reason": "系统定位服务未开启"])
      return
    }

    let status = currentLocationAuthorizationStatus()
    switch status {
    case .notDetermined:
      pendingLocationResult = result
      locationManager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      pendingLocationResult = result
      locationManager.requestLocation()
    case .denied, .restricted:
      result(["ok": false, "reason": "定位权限未开启"])
    @unknown default:
      result(["ok": false, "reason": "未知定位授权状态"])
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let result = pendingLocationResult else { return }
    switch currentLocationAuthorizationStatus() {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      pendingLocationResult = nil
      result(["ok": false, "reason": "定位权限未开启"])
    case .notDetermined:
      break
    @unknown default:
      pendingLocationResult = nil
      result(["ok": false, "reason": "未知定位授权状态"])
    }
  }

  private func currentLocationAuthorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let result = pendingLocationResult else { return }
    pendingLocationResult = nil
    guard let location = locations.last else {
      result(["ok": false, "reason": "未获取到定位结果"])
      return
    }
    result([
      "ok": true,
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
      "timestamp": location.timestamp.timeIntervalSince1970
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let result = pendingLocationResult else { return }
    pendingLocationResult = nil
    result(["ok": false, "reason": "定位失败：\(error.localizedDescription)"])
  }

  private func speak(text: String, voice: String, language: String, rate: Double) -> [String: Any] {
    let content = normalizeForSpeech(text)
    if content.isEmpty {
      return ["ok": false, "reason": "讲解词为空"]
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .spokenAudio,
        options: [.duckOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      return ["ok": false, "reason": "音频会话启动失败：\(error.localizedDescription)"]
    }

    let chunks = splitForSpeech(content)
    if chunks.isEmpty {
      return ["ok": false, "reason": "讲解词为空"]
    }

    speechSynthesizer.stopSpeaking(at: .immediate)
    for (index, chunk) in chunks.enumerated() {
      let utterance = AVSpeechUtterance(string: chunk)
      utterance.voice = bestVoice(for: voiceLanguage(for: language), profile: voice)
      applyVoiceProfile(voice, rate: rate, to: utterance)
      utterance.postUtteranceDelay = index < chunks.count - 1 ? pauseAfter(chunk) : 0.08
      speechSynthesizer.speak(utterance)
    }
    return ["ok": true]
  }

  private func voiceLanguage(for language: String) -> String {
    let normalized = language.lowercased()
    if normalized.hasPrefix("en") {
      return "en-US"
    }
    if normalized.hasPrefix("ja") {
      return "ja-JP"
    }
    if normalized.hasPrefix("fr") {
      return "fr-FR"
    }
    if normalized.hasPrefix("ko") {
      return "ko-KR"
    }
    return "zh-CN"
  }

  private func bestVoice(for language: String, profile: String) -> AVSpeechSynthesisVoice? {
    logSpeechVoicesIfNeeded()
    let allVoices = AVSpeechSynthesisVoice.speechVoices()
    let exactLanguageVoices = allVoices.filter { $0.language == language }
    let relatedChineseVoices = allVoices.filter { $0.language.hasPrefix("zh") }
    let candidates = exactLanguageVoices.isEmpty && language.hasPrefix("zh")
      ? relatedChineseVoices
      : exactLanguageVoices

    let preferredNames: [String]
    switch profile {
    case "young_male":
      preferredNames = ["Reed", "Eddy", "Rocko", "Grandpa", "Gordon", "Daniel"]
    case "young_female":
      preferredNames = ["Flo", "Sandy", "Shelley", "Tingting", "Meijia", "Sinji"]
    default:
      preferredNames = ["Tingting", "Flo", "Sandy", "Shelley", "Meijia"]
    }

    for preferredName in preferredNames {
      if let voice = candidates.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
        NSLog("SmartGuideTTS selected profile=\(profile) language=\(language) voice=\(voice.name) id=\(voice.identifier)")
        return voice
      }
    }

    let fallback = AVSpeechSynthesisVoice(language: language)
      ?? candidates.first
      ?? AVSpeechSynthesisVoice(language: "zh-CN")
    NSLog("SmartGuideTTS fallback profile=\(profile) language=\(language) voice=\(fallback?.name ?? "nil") id=\(fallback?.identifier ?? "nil")")
    return fallback
  }

  private func applyVoiceProfile(_ voice: String, rate: Double, to utterance: AVSpeechUtterance) {
    // 外部语速倍率（如 0.8/1.0/1.25），限幅避免过快过慢
    let multiplier = Float(min(max(rate, 0.5), 1.5))
    switch voice {
    case "young_male":
      utterance.rate = 0.40 * multiplier
      utterance.pitchMultiplier = 0.96
    case "young_female":
      utterance.rate = 0.41 * multiplier
      utterance.pitchMultiplier = 1.04
    default:
      utterance.rate = 0.39 * multiplier
      utterance.pitchMultiplier = 1.02
    }
    utterance.volume = 1.0
    utterance.preUtteranceDelay = 0.05
  }

  private func logSpeechVoicesIfNeeded() {
    guard !didLogSpeechVoices else { return }
    didLogSpeechVoices = true
    let voices = AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("zh") }
      .map { "\($0.name)<\($0.language)>[\($0.identifier)]" }
      .joined(separator: " | ")
    NSLog("SmartGuideTTS availableChineseVoices \(voices)")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    NSLog("SmartGuideTTS started voice=\(utterance.voice?.identifier ?? "default") rate=\(utterance.rate) pitch=\(utterance.pitchMultiplier) textLength=\(utterance.speechString.count)")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    NSLog("SmartGuideTTS finished textLength=\(utterance.speechString.count)")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    NSLog("SmartGuideTTS cancelled textLength=\(utterance.speechString.count)")
  }

  private func normalizeForSpeech(_ text: String) -> String {
    return text
      .replacingOccurrences(of: #"（[^）]*）"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"【[^】]*】"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"([（(]\s*[）)])"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"([#*_`>\-]+)"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: "AI", with: "A I")
      .replacingOccurrences(of: "TTS", with: "语音")
      .replacingOccurrences(of: "/", with: "，")
      .replacingOccurrences(of: "：", with: "，")
      .replacingOccurrences(of: ":", with: "，")
      .replacingOccurrences(of: "；", with: "。")
      .replacingOccurrences(of: ";", with: ".")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+([，。！？、])"#, with: "$1", options: .regularExpression)
      .replacingOccurrences(of: #"([，。！？、])\s+"#, with: "$1", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func splitForSpeech(_ text: String) -> [String] {
    var chunks: [String] = []
    var current = ""
    let softStops = Set(["，", ",", "、"])
    let hardStops = Set(["。", "！", "？", ".", "!", "?"])

    for scalar in text.unicodeScalars {
      let char = String(scalar)
      current.append(char)
      let shouldCut = hardStops.contains(char)
        || (softStops.contains(char) && current.count >= 34)
        || current.count >= 64

      if shouldCut {
        let chunk = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !chunk.isEmpty {
          chunks.append(chunk)
        }
        current = ""
      }
    }

    let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty {
      chunks.append(tail)
    }
    return chunks
  }

  private func pauseAfter(_ chunk: String) -> TimeInterval {
    guard let last = chunk.last else { return 0.16 }
    switch last {
    case "。", "！", "？", ".", "!", "?":
      return 0.34
    case "，", ",", "、":
      return 0.18
    default:
      return 0.14
    }
  }
}
