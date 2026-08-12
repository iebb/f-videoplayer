import AVFoundation
import AVKit
import Cocoa
import FlutterMacOS

/// A transparent, hit-test-free host keeps AVPlayerLayer attached to the
/// current Flutter window while AVKit owns the system Picture-in-Picture UI.
private final class FVideoPictureInPictureHostView: NSView {
  var playerLayer: AVPlayerLayer?

  override func layout() {
    super.layout()
    playerLayer?.frame = bounds
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return nil
  }
}

/// Native macOS implementation of F Video Player's shared system-PiP method channel.
///
/// The Flutter player uses a texture backend, so AVKit cannot adopt its layer
/// directly. This bridge creates a synchronized AVPlayer for the same local
/// stream, hands that player's layer to AVPictureInPictureController, and
/// reports the final playback position when PiP closes or restores.
public final class FVideoPictureInPicturePlugin: NSObject, FlutterPlugin,
  AVPictureInPictureControllerDelegate
{
  private let channel: FlutterMethodChannel
  private weak var rootView: NSView?
  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pictureInPictureController: AVPictureInPictureController?
  private var hostView: FVideoPictureInPictureHostView?
  private var activeId: String?
  private var pendingStartResult: FlutterResult?
  private var startTimeout: DispatchWorkItem?
  private var possibleObservation: NSKeyValueObservation?
  private var statusObservation: NSKeyValueObservation?
  private var preferredRate: Float = 1
  private var preferredPlaying = true
  private var restoreAccepted = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FVideoPictureInPicturePlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: instance.channel)
  }

  private init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: "f_videoplayer/picture_in_picture",
      binaryMessenger: registrar.messenger
    )
    rootView = registrar.view
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      self?.handleOnMain(call, result: result)
    }
  }

  private func handleOnMain(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isSupported":
      result(AVPictureInPictureController.isPictureInPictureSupported())
    case "prepare":
      result(prepare(call))
    case "startPrepared":
      startPrepared(call, result: result)
    case "update":
      update(call)
      result(nil)
    case "cancel":
      let id = (call.arguments as? [String: Any])?["id"] as? String
      if id == nil || id == activeId { stop(notifyFlutter: false) }
      result(nil)
    case "start":
      guard prepare(call) else {
        result(false)
        return
      }
      startPrepared(call, result: result)
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func prepare(_ call: FlutterMethodCall) -> Bool {
    guard
      AVPictureInPictureController.isPictureInPictureSupported(),
      let arguments = call.arguments as? [String: Any],
      let id = arguments["id"] as? String,
      let rawURL = arguments["url"] as? String,
      let url = URL(string: rawURL)
    else {
      return false
    }

    let replacingSession = activeId != nil && activeId != id
    stop(notifyFlutter: replacingSession)
    let player = AVPlayer(playerItem: AVPlayerItem(url: url))
    applyPlaybackArguments(arguments, to: player, shouldSeek: true)
    guard let attachment = attach(player: player) else { return false }
    activeId = id
    self.player = player
    playerLayer = attachment.layer
    pictureInPictureController = attachment.controller
    hostView = attachment.host
    return true
  }

  private func startPrepared(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let id = arguments["id"] as? String,
      id == activeId,
      let player,
      let controller = pictureInPictureController
    else {
      result(false)
      return
    }
    applyPlaybackArguments(arguments, to: player, shouldSeek: true)
    beginStart(player: player, controller: controller, result: result)
  }

  private func update(_ call: FlutterMethodCall) {
    guard
      let arguments = call.arguments as? [String: Any],
      let id = arguments["id"] as? String,
      id == activeId,
      let player
    else {
      return
    }
    applyPlaybackArguments(arguments, to: player, shouldSeek: true)
    applyPreferredPlaybackState(to: player)
  }

  private func applyPlaybackArguments(
    _ arguments: [String: Any],
    to player: AVPlayer,
    shouldSeek: Bool
  ) {
    if let volume = (arguments["volume"] as? NSNumber)?.doubleValue,
      volume.isFinite
    {
      player.volume = Float(min(1, max(0, volume)))
    }
    player.isMuted = arguments["muted"] as? Bool ?? false
    preferredRate = (arguments["speed"] as? NSNumber)?.floatValue ?? 1
    preferredPlaying = arguments["playing"] as? Bool ?? true
    guard shouldSeek else { return }
    let positionMs = (arguments["positionMs"] as? NSNumber)?.doubleValue ?? 0
    let currentMs = player.currentTime().seconds * 1000
    if positionMs > 0, !currentMs.isFinite || abs(currentMs - positionMs) > 750 {
      player.seek(
        to: CMTime(seconds: positionMs / 1000, preferredTimescale: 600),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      )
    }
  }

  private func applyPreferredPlaybackState(to player: AVPlayer) {
    if preferredPlaying {
      player.play()
      if preferredRate > 0, preferredRate != 1 { player.rate = preferredRate }
    } else {
      player.pause()
    }
  }

  private func beginStart(
    player: AVPlayer,
    controller: AVPictureInPictureController,
    result: @escaping FlutterResult
  ) {
    clearStartObservers()
    pendingStartResult = result
    applyPreferredPlaybackState(to: player)

    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.pendingStartResult != nil else { return }
      self.pendingStartResult?(false)
      self.pendingStartResult = nil
      self.stop(notifyFlutter: false)
    }
    startTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: timeout)

    possibleObservation = controller.observe(
      \.isPictureInPicturePossible,
      options: [.initial, .new]
    ) { [weak self, weak controller] _, _ in
      DispatchQueue.main.async {
        guard let self, let controller else { return }
        self.startIfPossible(controller)
      }
    }
    statusObservation = player.currentItem?.observe(
      \.status,
      options: [.initial, .new]
    ) { [weak self] item, _ in
      guard item.status == .failed else { return }
      DispatchQueue.main.async {
        self?.pendingStartResult?(false)
        self?.pendingStartResult = nil
        self?.stop(notifyFlutter: false)
      }
    }
  }

  private func startIfPossible(_ controller: AVPictureInPictureController) {
    guard
      pendingStartResult != nil,
      pictureInPictureController === controller,
      controller.isPictureInPicturePossible
    else {
      return
    }
    possibleObservation?.invalidate()
    possibleObservation = nil
    statusObservation?.invalidate()
    statusObservation = nil
    controller.startPictureInPicture()
  }

  private func clearStartObservers() {
    startTimeout?.cancel()
    startTimeout = nil
    possibleObservation?.invalidate()
    possibleObservation = nil
    statusObservation?.invalidate()
    statusObservation = nil
  }

  private func attach(
    player: AVPlayer
  ) -> (
    layer: AVPlayerLayer,
    controller: AVPictureInPictureController,
    host: FVideoPictureInPictureHostView
  )? {
    guard let rootView else { return nil }
    let host = FVideoPictureInPictureHostView(frame: rootView.bounds)
    host.autoresizingMask = [.width, .height]
    host.wantsLayer = true
    host.alphaValue = 0.01
    let layer = AVPlayerLayer(player: player)
    layer.frame = host.bounds
    layer.videoGravity = .resizeAspect
    host.playerLayer = layer
    host.layer?.addSublayer(layer)
    rootView.addSubview(host, positioned: .below, relativeTo: nil)
    guard let controller = AVPictureInPictureController(playerLayer: layer)
    else {
      host.removeFromSuperview()
      return nil
    }
    controller.delegate = self
    return (layer, controller, host)
  }

  private func stop(notifyFlutter: Bool = true) {
    clearStartObservers()
    pendingStartResult?(false)
    pendingStartResult = nil
    let stoppedId = activeId
    let stoppedPositionMs = positionMilliseconds(player)
    let wasRestored = restoreAccepted
    player?.pause()
    if pictureInPictureController?.isPictureInPictureActive == true {
      pictureInPictureController?.stopPictureInPicture()
    }
    pictureInPictureController?.delegate = nil
    pictureInPictureController = nil
    playerLayer?.player = nil
    playerLayer?.removeFromSuperlayer()
    playerLayer = nil
    hostView?.removeFromSuperview()
    hostView = nil
    player = nil
    activeId = nil
    preferredRate = 1
    preferredPlaying = true
    restoreAccepted = false
    if notifyFlutter, let stoppedId {
      channel.invokeMethod(
        "didStop",
        arguments: [
          "id": stoppedId,
          "positionMs": stoppedPositionMs,
          "restored": wasRestored,
        ]
      )
    }
  }

  public func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.clearStartObservers()
      self?.pendingStartResult?(true)
      self?.pendingStartResult = nil
    }
  }

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.pendingStartResult?(false)
      self?.pendingStartResult = nil
      self?.stop(notifyFlutter: false)
    }
  }

  public func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    DispatchQueue.main.async { [weak self] in self?.stop() }
  }

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
      completionHandler: @escaping (Bool) -> Void
  ) {
    guard let activeId, let player else {
      completionHandler(false)
      return
    }
    let requestedId = activeId
    var completed = false
    let finish: (Bool) -> Void = { [weak self] restored in
      guard !completed else { return }
      completed = true
      let validSession = self?.activeId == requestedId
      let accepted = restored && validSession
      if validSession { self?.restoreAccepted = accepted }
      completionHandler(accepted)
    }
    let timeout = DispatchWorkItem { finish(false) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
    channel.invokeMethod(
      "restoreRequested",
      arguments: [
        "id": requestedId,
        "positionMs": positionMilliseconds(player),
        "playing": player.timeControlStatus != .paused,
        "speed": preferredRate,
        "volume": player.volume,
        "muted": player.isMuted,
      ]
    ) { response in
      DispatchQueue.main.async {
        timeout.cancel()
        finish((response as? NSNumber)?.boolValue ?? false)
      }
    }
  }

  private func positionMilliseconds(_ player: AVPlayer?) -> Int64 {
    guard let seconds = player?.currentTime().seconds, seconds.isFinite else {
      return 0
    }
    return Int64(max(0, (seconds * 1000).rounded()))
  }
}
