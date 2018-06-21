//  Player.swift
//
//  Created by patrick piemonte on 11/26/14.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014-present patrick piemonte (http://patrickpiemonte.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#if canImport(AppKit)
    import AppKit
#else
    import UIKit
#endif
import AVFoundation
import AVKit
import CoreGraphics

// MARK: - PlayerDelegate

/// Player delegate protocol
@objc
public protocol PlayerDelegate: NSObjectProtocol {
    @objc optional func playerReady(player: Player)
    @objc optional func playerPlaybackError(player: Player, error: NSError?)
    @objc optional func playerPlaybackStateDidChange(player: Player)
    @objc optional func playerBufferingStateDidChange(player: Player)

    // This is the time in seconds that the video has been buffered.
    // If implementing a UIProgressView, use this value / player.maximumDuration to set progress.
    @objc optional func playerBufferTimeDidChange(bufferTime: Double)
}

// MARK: - PlayerPlaybackDelegate

/// Player playback protocol
@objc
public protocol PlayerPlaybackDelegate: NSObjectProtocol {
    @objc optional func playerCurrentTimeDidChange(player: Player)
    @objc optional func playerPlaybackWillStartFromBeginning(player: Player)
    @objc optional func playerPlaybackDidEnd(player: Player)
    @objc optional func playerPlaybackWillLoop(player: Player)
}

extension String {
    var withSentenceCasing: String {
        return prefix(1).capitalized + dropFirst()
    }
}

// MARK: - Player

/// ▶️ Player, simple way to play and stream media
open class Player: Player.ViewController {

    // MARK: - Type Aliases

    #if canImport(AppKit)
        public typealias ViewController = NSViewController
        fileprivate typealias PlayerView = AVPlayerView
        public typealias Image = NSImage
        public typealias Color = NSColor
        public typealias SnapshotResult = Image?
        public typealias NibName = NSNib.Name?
    #else
        public typealias ViewController = UIViewController
        fileprivate typealias PlayerView = SuperSecretPlayerView?
        public typealias Image = UIImage
        public typealias Color = UIColor
        public typealias SnapshotResult = Image
        public typealias NibName = String?
    #endif

    // MARK: - Types

    /// Asset playback states.
    public enum PlaybackState: String, CustomStringConvertible {
        case stopped
        case playing
        case paused
        case failed

        public var description: String {
            return rawValue.withSentenceCasing
        }
    }

    /// Asset buffering states.
    public enum BufferingState: String, CustomStringConvertible {
        case unknown
        case ready
        case delayed

        public var description: String {
            return rawValue.withSentenceCasing
        }
    }

    /// Video fill mode options for the `fillMode` property.
    public enum FillMode: String, CustomStringConvertible {
        /// Specifies that the video should be stretched to fill the layer’s bounds.
        case resizeStretch    = "AVLayerVideoGravityResize"
        /// Specifies that the player should preserve the video’s aspect ratio and fill the layer’s bounds.
        case resizeAspectFill = "AVLayerVideoGravityResizeAspectFill"
        /// Specifies that the player should preserve the video’s aspect ratio and fit the video within the layer’s bounds.
        case resizeAspectFit  = "AVLayerVideoGravityResizeAspect"

        fileprivate var avLayerVideoGravityValue: AVLayerVideoGravity {
            return AVLayerVideoGravity(rawValue: self.rawValue)
        }

        public var description: String {
            switch self {
            case .resizeStretch:
                return "resizeStretch"
            case .resizeAspectFill:
                return "resizeAspectFill"
            case .resizeAspectFit:
                return "resizeAspectFit"
            }
        }
    }

    // MARK: - Properties

    /// Player delegate.
    open weak var playerDelegate: PlayerDelegate?

    /// Playback delegate.
    open weak var playbackDelegate: PlayerPlaybackDelegate?

    // MARK: Configuration

    /// Use the native UI
    ///
    /// - Parameter bool: defaults to true
    open var useNativeUI: Bool = true

    /// Local or remote URL for the file asset to be played.
    ///
    /// - Parameter url: URL of the asset.
    open var url: URL? {
        didSet {
            setup(url: url)
        }
    }

    /// Determines if the video should autoplay when a url is set
    ///
    /// - Parameter bool: defaults to true
    open var autoplay: Bool = true

    /// For setting up with AVAsset instead of URL
    ///
    /// Note: Resets URL (cannot set both)
    open var asset: AVAsset? {
        get { return avAsset }
        set { _ = newValue.map { setupAsset($0) } }
    }

    /// Mutes audio playback when true.
    open var muted: Bool {
        get {
            return avPlayer.isMuted
        }
        set {
            avPlayer.isMuted = newValue
        }
    }

    /// Volume for the player, ranging from 0.0 to 1.0 on a linear scale.
    open var volume: Float {
        get {
            return avPlayer.volume
        }
        set {
            avPlayer.volume = newValue
        }
    }

    /// Specifies how the video is displayed within a player layer’s bounds.
    /// The default value is `.resizeAspectFit`. See the `FillMode` enum.
    open var fillMode: FillMode {
        get {
            #if canImport(AppKit)
                return FillMode(rawValue: playerView.videoGravity)!
            #else
                if let playerVC = nativePlayerViewController {
                    return FillMode(rawValue: playerVC.videoGravity)!
                }

                return FillMode(rawValue: playerView!.fillMode.rawValue)!
            #endif
        }
        set {
            #if canImport(AppKit)
                playerView.videoGravity = newValue.rawValue
            #else
                if let playerVC = nativePlayerViewController {
                    playerVC.videoGravity = newValue.rawValue
                } else {
                    playerView!.fillMode = newValue.avLayerVideoGravityValue
                }
            #endif
        }
    }

    /// Player view's initial background color.
    open var layerBackgroundColor: Color? {
        get {
            var color: Color?
            #if canImport(AppKit)
                if let backgroundColor = playerView.layer?.backgroundColor {
                    color = Color(cgColor: backgroundColor)
                }
            #else
                if let nativePlayerViewController = nativePlayerViewController {
                    color = nativePlayerViewController.view.backgroundColor
                } else {
                    color = playerView!.playerBackgroundColor
                }
            #endif

            return color
        }
        set {
            #if canImport(AppKit)
                playerView.layer?.backgroundColor = newValue?.cgColor
            #else
                if let playerVC = nativePlayerViewController {
                    playerVC.view.backgroundColor = newValue
                } else {
                    playerView!.playerBackgroundColor = newValue
                    // playerView.playerLayer.backgroundColor = newValue?.cgColor
                }
            #endif
        }
    }

    #if canImport(AppKit)
    /// The player view’s controls style.
    ///
    /// The player view supports a number of different control styles that you can use to customize the player view’s appearance and behavior. See `AVPlayerViewControlsStyle` for the possible values. The default value of this property is `.default`
    ///
    /// - Important: Only available on the macOS platform.
    open var controlsStyle: AVPlayerViewControlsStyle {
        get {
            return playerView.controlsStyle
        }
        set {
            playerView.controlsStyle = newValue
        }
    }
    #endif

    /// Pauses playback automatically when resigning active.
    ///
    /// The default value of this property is `true`.
    open var playbackPausesWhenResigningActive: Bool = true

    /// Pauses playback automatically when backgrounded (on macOS, when hidden).
    ///
    /// The default value of this property is `true`.
    open var playbackPausesWhenBackgrounded: Bool = true

    /// Resumes playback when became active.
    ///
    /// The default value of this property is `true`.
    open var playbackResumesWhenBecameActive: Bool = true

    /// Resumes playback when entering foreground. (on macOS, when unhidden)
    ///
    /// The default value of this property is `true`.
    open var playbackResumesWhenEnteringForeground: Bool = true

    // MARK: State

    /// Whether the player is currently playing.
    /// Returns `true` if the `playbackState` is `.playing`.
    open var isPlaying: Bool {
        return playbackState == .playing
    }

    /// Playback automatically loops continuously when true.
    open var playbackLoops: Bool {
        get {
            return avPlayer.actionAtItemEnd == .none
        }
        set {
            if newValue {
                avPlayer.actionAtItemEnd = .none
            } else {
                avPlayer.actionAtItemEnd = .pause
            }
        }
    }

    /// Playback freezes on last frame frame at end when true.
    ///
    /// The default value of this property is `false`.
    open var playbackFreezesAtEnd: Bool = false

    /// Current playback state of the Player.
    open var playbackState: PlaybackState = .stopped {
        didSet {
            if playbackState != oldValue || !playbackEdgeTriggered {
                playerDelegate?.playerPlaybackStateDidChange?(player: self)
            }
        }
    }

    /// Current buffering state of the Player.
    open var bufferingState: BufferingState = .unknown {
        didSet {
            if bufferingState != oldValue || !playbackEdgeTriggered {
                playerDelegate?.playerBufferingStateDidChange?(player: self)
            }
        }
    }

    /// Playback buffering size in seconds.
    open var bufferSize: Double = 10

    /// Playback is not automatically triggered from state changes when true.
    open var playbackEdgeTriggered: Bool = true

    /// Maximum duration of playback.
    open var maximumDuration: TimeInterval {
        if let playerItem = avPlayerItem {
            return CMTimeGetSeconds(playerItem.duration)
        } else {
            return CMTimeGetSeconds(kCMTimeIndefinite)
        }
    }

    /// Media playback's current time.
    open var currentTime: TimeInterval {
        if let playerItem = avPlayerItem {
            return CMTimeGetSeconds(playerItem.currentTime())
        } else {
            return CMTimeGetSeconds(kCMTimeIndefinite)
        }
    }

    /// The natural dimensions of the media.
    ///
    /// - Note: The `avPlayerItem` must exist and have had its tracks loaded.
    ///
    open var naturalSize: CGSize? {
        if let playerItem = avPlayerItem,
            let track = playerItem.asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            return CGSize(width: fabs(size.width), height: fabs(size.height))
        }
        return nil
    }

    // MARK: Public Objects

    public var avPlayer: AVPlayer
    public var avPlayerItem: AVPlayerItem?
    #if canImport(UIKit)
        public var nativePlayerViewController: AVPlayerViewController?
    #endif

    // MARK: Private Objects

    fileprivate var avAsset: AVAsset? {
        didSet {
            if avAsset != nil {
                setupPlayerItem(nil)
            }
        }
    }

    fileprivate var timeObserver: Any?
    fileprivate var playerView: PlayerView
    fileprivate var seekTimeRequested: CMTime?
    fileprivate var lastBufferTime: Double = 0

    // Boolean that determines if the user or calling coded has trigged autoplay manually.
    fileprivate var hasAutoplayActivated: Bool = true

    #if canImport(AppKit)
        fileprivate weak var avPlayerLayer: AVPlayerLayer?
        fileprivate var playerViewObservation: NSKeyValueObservation!
    #endif

    // MARK: - Object Lifecycle

    public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        avPlayer = AVPlayer()
        #if canImport(AppKit)
            playerView = PlayerView()
        #else
            playerView = SuperSecretPlayerView()
        #endif

        super.init(coder: aDecoder)

        sharedInit()
    }

    public override init(nibName nibNameOrNil: NibName, bundle nibBundleOrNil: Bundle?) {
        avPlayer = AVPlayer()
        #if canImport(AppKit)
            playerView = PlayerView()
        #else
            playerView = SuperSecretPlayerView()
        #endif

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        sharedInit()
    }

    private func sharedInit() {
        avPlayer.actionAtItemEnd = .pause
        timeObserver = nil
        fillMode = .resizeAspectFit

        #if canImport(AppKit)
            playerView.player = avPlayer
            playerView.controlsStyle = .default
        #endif
    }

    deinit {
        avPlayer.pause()
        setupPlayerItem(nil)

        removePlayerObservers()

        playerDelegate = nil
        removeApplicationObservers()

        playbackDelegate = nil
        removePlayerLayerObservers()

        #if canImport(AppKit)
            playerView.player = nil
        #else
            if let playerVC = nativePlayerViewController {
                playerVC.player = nil
                nativePlayerViewController = nil
            } else {
                playerView!.player = nil
                playerView = nil
            }
        #endif
    }

    /// A convenience method for adding a player to the given view controller.
    /// The player will be added to `viewController`'s `childViewControllers` array and its view hierarchy.
    ///
    /// - Parameter viewController: The parent view controller that the player will be added to.
    open func add(to viewController: ViewController) {
        viewController.addChildViewController(self)

        #if canImport(UIKit)
            didMove(toParentViewController: viewController)
        #endif

        viewController.view.addSubview(view)
    }

    // MARK: - View Lifecycle

    open override func loadView() {
        #if canImport(AppKit)
            view = playerView
        #else
            if useNativeUI {
                super.loadView()
            } else {
                view = playerView
            }
        #endif
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        #if canImport(UIKit)
            if useNativeUI {
                let playerViewController = AVPlayerViewController()

                addChildViewController(playerViewController)
                playerViewController.didMove(toParentViewController: self)

                playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(playerViewController.view)

                NSLayoutConstraint.activate([
                    playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])

                nativePlayerViewController = playerViewController
            } else {
                playerView!.playerIsHidden = false
            }
        #endif

        if let url = url {
            setup(url: url)
        } else if let asset = asset {
            setupAsset(asset)
        }

        addPlayerLayerObservers()
        addPlayerObservers()
        addApplicationObservers()
    }

    #if canImport(AppKit)
        open override func viewDidDisappear() {
            super.viewDidDisappear()

            if playbackState == .playing {
                pause()
            }
        }

    #else
        open override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)

            if playbackState == .playing {
                pause()
            }
        }
    #endif

    // MARK: - Playback Methods

    #if canImport(UIKit)
        open func PlayerViewSet(player: AVPlayer) {
            if let playerVC = nativePlayerViewController {
                playerVC.player = player
                playerVC.view.isHidden = false
            } else {
                playerView!.player = player
                playerView!.playerIsHidden = false
            }
        }
    #endif

    /// Begins playback of the media from the beginning.
    open func playFromBeginning() {
        playbackDelegate?.playerPlaybackWillStartFromBeginning?(player: self)
        avPlayer.seek(to: kCMTimeZero)
        playFromCurrentTime()
    }

    /// Begins playback of the media from the current time.
    open func playFromCurrentTime() {
        if !autoplay {
            // external call to this method with auto play off.  activate it before calling play
            hasAutoplayActivated = true
        }
        play()
    }

    fileprivate func play() {
        if autoplay || hasAutoplayActivated {
            playbackState = .playing
            avPlayer.play()
        }
    }

    /// Pauses playback of the media.
    open func pause() {
        if playbackState != .playing {
            return
        }

        avPlayer.pause()
        playbackState = .paused
    }

    /// Stops playback of the media.
    open func stop() {
        if playbackState == .stopped {
            return
        }

        avPlayer.pause()
        playbackState = .stopped
        playbackDelegate?.playerPlaybackDidEnd?(player: self)
    }

    /// Updates playback to the specified time.
    ///
    /// - Parameters:
    ///   - time: The time to switch to move the playback.
    ///   - completionHandler: Call block handler after seeking/
    open func seek(to time: CMTime, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        if let playerItem = avPlayerItem {
            return playerItem.seek(to: time, completionHandler: completionHandler)
        } else {
            seekTimeRequested = time
        }
    }

    /// Sets the current playback time to the specified second mark and executes the specified block when the seek operation completes or is interrupted.
    ///
    /// - Parameters:
    ///   - time: The time (in seconds) to seek to.
    ///   - completionHandler: Call block handler after seeking.
    open func seek(toSecond second: Int, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        let cmTime = CMTimeMake(Int64(second), 1)
        if let completionHandler = completionHandler {
            avPlayer.seek(to: cmTime, completionHandler: completionHandler)
        } else {
            avPlayer.seek(to: cmTime)
        }
    }

    /// Updates the playback time to the specified time bound.
    ///
    /// - Parameters:
    ///   - time: The time to switch to move the playback.
    ///   - toleranceBefore: The tolerance allowed before time.
    ///   - toleranceAfter: The tolerance allowed after time.
    ///   - completionHandler: call block handler after seeking
    open func seekToTime(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Swift.Void)? = nil) {
        if let playerItem = avPlayerItem {
            return playerItem.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
        }
    }

    /// Captures a snapshot of the current player view.
    ///
    /// - Returns: A image of the player view.
    open func takeSnapshot() -> SnapshotResult {
        var image: SnapshotResult
        #if canImport(AppKit)
            if let playerItem = avPlayerItem {
                let imageGenerator = AVAssetImageGenerator(asset: playerItem.asset)
                if let cgImage = try? imageGenerator.copyCGImage(at: playerItem.currentTime(), actualTime: nil) {
                    image = NSImage(cgImage: cgImage, size: playerView.visibleRect.size)
                }
            }
        #else
            if let playerVC = nativePlayerViewController {
                UIGraphicsBeginImageContextWithOptions(playerVC.view.frame.size, false, UIScreen.main.scale)
                playerVC.view.drawHierarchy(in: playerVC.view.bounds, afterScreenUpdates: true)
            } else {
                UIGraphicsBeginImageContextWithOptions(playerView!.frame.size, false, UIScreen.main.scale)
                playerView!.drawHierarchy(in: playerView!.bounds, afterScreenUpdates: true)
            }
            image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        #endif

        return image
    }

    /// Return the `AVPlayerLayer` for consumption by things such as Picture in Picture.
    ///
    /// - Note: Player must be loaded.
    open func playerLayer() -> AVPlayerLayer? {
        #if canImport(AppKit)
            return avPlayerLayer
        #else
            return playerView!.playerLayer
        #endif
    }
}

// MARK: - Setup Methods

fileprivate extension Player {
    func setup(url: URL?) {
        guard isViewLoaded else { return }

        // ensure everything is reset beforehand
        if playbackState == .playing {
            pause()
        }

        // Reset autoplay flag since a new url is set.
        hasAutoplayActivated = false

        if autoplay {
            playbackState = .playing
        } else {
            playbackState = .stopped
        }

        setupPlayerItem(nil)

        if let url = url {
            let asset = AVURLAsset(url: url, options: .none)
            setupAsset(asset)
        }
    }

    func setupAsset(_ asset: AVAsset) {
        guard isViewLoaded else { return }

        if playbackState == .playing {
            pause()
        }

        bufferingState = .unknown
        avAsset = asset

        let keys = [AssetTracksKey, AssetPlayableKey, AssetDurationKey, AssetRateKey]
        avAsset?.loadValuesAsynchronously(forKeys: keys) { () -> Void in
            for key in keys {
                var error: NSError?
                let status = self.avAsset?.statusOfValue(forKey: key, error: &error)
                if status == .failed {
                    self.playerDelegate?.playerPlaybackError?(player: self, error: error)
                    self.playbackState = .failed
                    return
                }
            }

            if let asset = self.avAsset {
                if !asset.isPlayable {
                    self.playbackState = .failed
                    return
                }

                let playerItem = AVPlayerItem(asset: asset)
                self.setupPlayerItem(playerItem)
            }
        }
    }

    func setupPlayerItem(_ playerItem: AVPlayerItem?) {
        avPlayerItem?.removeObserver(self, forKeyPath: PlayerItemEmptyBufferKey, context: &PlayerItemObserverContext)
        avPlayerItem?.removeObserver(self, forKeyPath: PlayerItemKeepUpKey, context: &PlayerItemObserverContext)
        avPlayerItem?.removeObserver(self, forKeyPath: PlayerItemStatusKey, context: &PlayerItemObserverContext)
        avPlayerItem?.removeObserver(self, forKeyPath: PlayerItemLoadedTimeRangesKey, context: &PlayerItemObserverContext)

        if let currentPlayerItem = avPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: currentPlayerItem)
        }

        avPlayerItem = playerItem

        if let requestedSeekTime = seekTimeRequested, avPlayerItem != nil {
            seekTimeRequested = nil
            seek(to: requestedSeekTime)
        }

        avPlayerItem?.addObserver(self, forKeyPath: PlayerItemEmptyBufferKey, options: [.new, .old], context: &PlayerItemObserverContext)
        avPlayerItem?.addObserver(self, forKeyPath: PlayerItemKeepUpKey, options: [.new, .old], context: &PlayerItemObserverContext)
        avPlayerItem?.addObserver(self, forKeyPath: PlayerItemStatusKey, options: [.new, .old], context: &PlayerItemObserverContext)
        avPlayerItem?.addObserver(self, forKeyPath: PlayerItemLoadedTimeRangesKey, options: [.new, .old], context: &PlayerItemObserverContext)

        if let updatedPlayerItem = avPlayerItem {
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: updatedPlayerItem)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: updatedPlayerItem)
        }

        avPlayer.replaceCurrentItem(with: avPlayerItem)

        // update new playerItem settings
        if playbackLoops {
            avPlayer.actionAtItemEnd = .none
        } else {
            avPlayer.actionAtItemEnd = .pause
        }
    }
}

// MARK: - Notifications

private extension Player {

    // MARK: AVPlayerItem

    @objc
    func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        if playbackLoops {
            playbackDelegate?.playerPlaybackWillLoop?(player: self)
            avPlayer.seek(to: kCMTimeZero)
        } else {
            if playbackFreezesAtEnd {
                stop()
            } else {
                avPlayer.seek(to: kCMTimeZero) { _ in
                    self.stop()
                }
            }
        }
    }

    @objc
    func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        playbackState = .failed
    }

    // MARK: UIApplication/NSApplication

    func addApplicationObservers() {
        #if canImport(AppKit)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: NSApplication.willResignActiveNotification, object: NSApp)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: NSApp)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidEnterBackground(_:)), name: NSApplication.didHideNotification, object: NSApp)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground(_:)), name: NSApplication.willUnhideNotification, object: NSApp)
        #else
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: .UIApplicationWillResignActive, object: UIApplication.shared)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: UIApplication.shared)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: UIApplication.shared)
            NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object: UIApplication.shared)
        #endif
    }

    func removeApplicationObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Notification Handlers

    @objc
    func handleApplicationWillResignActive(_ aNotification: Notification) {
        if playbackState == .playing && playbackPausesWhenResigningActive {
            pause()
        }
    }

    @objc
    func handleApplicationDidBecomeActive(_ aNotification: Notification) {
        if playbackState != .playing && playbackResumesWhenBecameActive {
            play()
        }
    }

    @objc
    func handleApplicationDidEnterBackground(_ aNotification: Notification) {
        if playbackState == .playing && playbackPausesWhenBackgrounded {
            pause()
        }
    }

    @objc
    func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        if playbackState != .playing && playbackResumesWhenEnteringForeground {
            play()
        }
    }
}

// MARK: - KVO

// KVO contexts
private var PlayerObserverContext: Int?
private var PlayerItemObserverContext: Int?
private var PlayerLayerObserverContext: Int?

// KVO asset keys
private let AssetTracksKey = #keyPath(AVAsset.tracks)
private let AssetPlayableKey = #keyPath(AVAsset.isPlayable)
private let AssetDurationKey = #keyPath(AVAsset.duration)
private let AssetRateKey = #keyPath(AVAsset.preferredRate)

// KVO player item keys
private let PlayerItemStatusKey = #keyPath(AVPlayerItem.status)
private let PlayerItemEmptyBufferKey = #keyPath(AVPlayerItem.playbackBufferEmpty)
private let PlayerItemKeepUpKey = #keyPath(AVPlayerItem.playbackLikelyToKeepUp)
private let PlayerItemLoadedTimeRangesKey = #keyPath(AVPlayerItem.loadedTimeRanges)

// KVO player keys
private let PlayerRateKey = #keyPath(AVPlayer.rate)

// KVO player layer keys
private let PlayerLayerReadyForDisplayKey = #keyPath(AVPlayerLayer.isReadyForDisplay)

private extension Player {

    // MARK: AVPlayerViewObservers

    func addPlayerLayerObservers() {
        #if canImport(AppKit)
            // Should work, but doesn't... radar://41298723
//            playerView.addObserver(self, forKeyPath: #keyPath(AVPlayerView.isReadyForDisplay), context: &PlayerLayerObserverContext)

            // Current workaround.
            playerViewObservation = playerView.observe(\.layer, options: [.new]) { [weak self] playerView, _ in
                if let avPlayerLayer = playerView.layer?.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer,
                    let strongSelf = self {
                    strongSelf.playerViewObservation.invalidate()
                    avPlayerLayer.addObserver(strongSelf, forKeyPath: PlayerLayerReadyForDisplayKey, context: &PlayerLayerObserverContext)
                    strongSelf.avPlayerLayer = avPlayerLayer
                }
            }
        #else
            if let playerVC = nativePlayerViewController {
                playerVC.addObserver(self, forKeyPath: PlayerLayerReadyForDisplayKey, options: [.new, .old], context: &PlayerLayerObserverContext)
            } else {
                playerView!.layer.addObserver(self, forKeyPath: PlayerLayerReadyForDisplayKey, options: [.new, .old], context: &PlayerLayerObserverContext)
            }
        #endif
    }

    func removePlayerLayerObservers() {
        #if canImport(AppKit)
            avPlayerLayer?.removeObserver(self, forKeyPath: PlayerLayerReadyForDisplayKey, context: &PlayerLayerObserverContext)
        #else
            if let playerVC = nativePlayerViewController {
                playerVC.view.removeObserver(self, forKeyPath: PlayerLayerReadyForDisplayKey, context: &PlayerLayerObserverContext)
            } else {
                playerView!.layer.removeObserver(self, forKeyPath: PlayerLayerReadyForDisplayKey, context: &PlayerLayerObserverContext)
            }
        #endif
    }

    // MARK: AVPlayerObservers

    func addPlayerObservers() {
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 100), queue: DispatchQueue.main) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.playbackDelegate?.playerCurrentTimeDidChange?(player: strongSelf)
        }
        avPlayer.addObserver(self, forKeyPath: PlayerRateKey, options: [.new, .old], context: &PlayerObserverContext)
    }

    func removePlayerObservers() {
        if let observer = timeObserver {
            avPlayer.removeTimeObserver(observer)
        }
        avPlayer.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)
    }
}

extension Player {
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // AssetRateKey, PlayerObserverContext
        if context == &PlayerItemObserverContext {
            // PlayerItemStatusKey
            if keyPath == PlayerItemKeepUpKey {
                // PlayerItemKeepUpKey
                if let item = avPlayerItem {
                    if item.isPlaybackLikelyToKeepUp {
                        bufferingState = .ready

                        // Don't want this on macOS (not only does `AVPlayerView` handle it for us, this causes
                        // unwanted interaction with keyboard shortcuts for controlling playback).
                        #if canImport(UIKit)
                        if playbackState == .playing {
                            playFromCurrentTime()
                        }
                        #endif
                    }
                }

                if let status = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    switch status.intValue as AVPlayerStatus.RawValue {
                        #if canImport(UIKit)
                        case AVPlayerStatus.readyToPlay.rawValue:
                            // TODO
                            PlayerViewSet(player: avPlayer)
//                            playerView.playerLayer.player = avPlayer
//                            playerView.playerLayer.isHidden = false
                        #endif
                    case AVPlayerStatus.failed.rawValue:
                        playbackState = PlaybackState.failed
                    default:
                        break
                    }
                }
            } else if keyPath == PlayerItemEmptyBufferKey {
                // PlayerItemEmptyBufferKey
                if let item = avPlayerItem {
                    if item.isPlaybackBufferEmpty {
                        bufferingState = .delayed
                    }
                }

                if let status = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    switch status.intValue as AVPlayerStatus.RawValue {
                        #if canImport(UIKit)
                        case AVPlayerStatus.readyToPlay.rawValue:
                            // TODO
                             PlayerViewSet(player: avPlayer)
//                            playerView.playerLayer.player = avPlayer
//                            playerView.playerLayer.isHidden = false
                        #endif
                    case AVPlayerStatus.failed.rawValue:
                        playbackState = PlaybackState.failed
                    default:
                        break
                    }
                }
            } else if keyPath == PlayerItemLoadedTimeRangesKey {
                // PlayerItemLoadedTimeRangesKey
                if let item = avPlayerItem {
                    bufferingState = .ready

                    let timeRanges = item.loadedTimeRanges
                    if let timeRange = timeRanges.first?.timeRangeValue {
                        let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                        if lastBufferTime != bufferedTime {
                            executeClosureOnMainQueueIfNecessary {
                                self.playerDelegate?.playerBufferTimeDidChange?(bufferTime: bufferedTime)
                            }
                            lastBufferTime = bufferedTime
                        }
                    }

                    // Don't want this on macOS (not only does `AVPlayerView` handle it for us, this causes
                    // unwanted interaction with keyboard shortcuts for controlling playback).
                    #if canImport(UIKit)
                        let currentTime = CMTimeGetSeconds(item.currentTime())
                        if ((lastBufferTime - currentTime) >= bufferSize ||
                                lastBufferTime == maximumDuration ||
                                timeRanges.first == nil)
                            && playbackState == .playing {

                            play()
                        }
                    #endif
                }
            }
        } else if context == &PlayerLayerObserverContext {
            #if canImport(AppKit)
                let isReadyForDisplay = playerView.isReadyForDisplay
            #else
                let isReadyForDisplay = nativePlayerViewController?.isReadyForDisplay
                    ?? playerView!.playerLayer.isReadyForDisplay
            #endif

            if isReadyForDisplay {
                executeClosureOnMainQueueIfNecessary {
                    self.playerDelegate?.playerReady?(player: self)
                }
            }
        } else if context == &PlayerObserverContext {
            // Currently, only observed on the macOS platform.
            // Needed for interaction with controls or keyboard shortcuts.
            if keyPath == PlayerRateKey {
                if avPlayer.rate == 0 {
                    playbackState = .paused
                } else {
                    playbackState = .playing
                }
            }
        }
    }

}

// MARK: - Dispatch

extension Player {
    public func executeClosureOnMainQueueIfNecessary(withClosure closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async(execute: closure)
        }
    }
}

// MARK: - PlayerView (UIKit)

#if canImport(UIKit)
    internal class SuperSecretPlayerView: UIView {

        // MARK: - Properties

        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        var player: AVPlayer? {
            get {
                return playerLayer.player
            }
            set {
                playerLayer.player = newValue
            }
        }

        var fillMode: AVLayerVideoGravity {
            get {
                return playerLayer.videoGravity
            }
            set {
                playerLayer.videoGravity = newValue
            }
        }

        var playerIsReadyForDisplay: Bool {
            get {
                return self.playerLayer.isReadyForDisplay
            }
        }

        var playerIsHidden: Bool {
            get {
                return self.playerLayer.isHidden
            }
            set {
                self.playerLayer.isHidden = newValue
            }
        }

        var playerBackgroundColor: UIColor? {
            get {
                if let cgColor = self.playerLayer.backgroundColor {
                    return UIColor(cgColor: cgColor)
                }
                return nil
            }
            set {
                self.playerLayer.backgroundColor = newValue?.cgColor
            }
        }

        var playerFillMode: String {
            get {
                return self.playerLayer.fillMode
            }
            set {
                self.playerLayer.fillMode = newValue
            }
        }

        // MARK: - Object Lifecycle

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerBackgroundColor = .black
            playerFillMode = Player.FillMode.resizeAspectFit.rawValue
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            playerBackgroundColor = .black
            playerFillMode = Player.FillMode.resizeAspectFit.rawValue
        }

        deinit {
            player?.pause()
            player = nil
        }
    }
#endif
