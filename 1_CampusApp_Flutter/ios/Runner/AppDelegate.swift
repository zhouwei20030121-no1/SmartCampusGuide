import Flutter
import UIKit
import AVFoundation
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private let ttsChannelName = "smart_campus_guide/tts"
  private let locationChannelName = "smart_campus_guide/location"
  private let speechSynthesizer = AVSpeechSynthesizer()
  private let locationManager = CLLocationManager()
  private var ttsChannel: FlutterMethodChannel?
  private var locationChannel: FlutterMethodChannel?
  private var pendingLocationResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupTtsChannel(messenger: controller.binaryMessenger)
      setupLocationChannel(messenger: controller.binaryMessenger)
    }
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
        result(self.speak(text: text, voice: voice, language: language))
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

  private func speak(text: String, voice: String, language: String) -> [String: Any] {
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
      utterance.voice = bestVoice(for: voiceLanguage(for: language))
      applyVoiceProfile(voice, to: utterance)
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
    return "zh-CN"
  }

  private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
    let candidates = AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language == language }
      .sorted { lhs, rhs in lhs.quality.rawValue > rhs.quality.rawValue }
    return candidates.first ?? AVSpeechSynthesisVoice(language: language)
  }

  private func applyVoiceProfile(_ voice: String, to utterance: AVSpeechUtterance) {
    switch voice {
    case "young_male":
      utterance.rate = 0.41
      utterance.pitchMultiplier = 0.94
    case "young_female":
      utterance.rate = 0.40
      utterance.pitchMultiplier = 1.04
    default:
      utterance.rate = 0.39
      utterance.pitchMultiplier = 0.99
    }
    utterance.volume = 1.0
    utterance.preUtteranceDelay = 0.05
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
