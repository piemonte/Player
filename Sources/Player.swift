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

import UIKit
import Foundation
import AVFoundation
import CoreGraphics

// MARK: - types

/// Video fill mode options for `Player.fillMode`.
///
/// - resize: Stretch to fill.
/// - resizeAspectFill: Preserve aspect ratio, filling bounds.
/// - resizeAspectFit: Preserve aspect ratio, fill within bounds.
public enum FillMode: String {
    case resize = "AVLayerVideoGravityResize"
    case resizeAspectFill = "AVLayerVideoGravityResizeAspectFill"
    case resizeAspectFit = "AVLayerVideoGravityResizeAspect"
}

/// Asset playback states.
public enum PlaybackState: Int, CustomStringConvertible {
    case stopped = 0
    case playing
    case paused
    case failed

    public var description: String {
        get {
            switch self {
            case .stopped:
                return "Stopped"
            case .playing:
                return "Playing"
            case .failed:
                return "Failed"
            case .paused:
                return "Paused"
            }
        }
    }
}

/// Asset buffering states.
public enum BufferingState: Int, CustomStringConvertible {
    case unknown = 0
    case ready
    case delayed

    public var description: String {
        get {
            switch self {
            case .unknown:
                return "Unknown"
            case .ready:
                return "Ready"
            case .delayed:
                return "Delayed"
            }
        }
    }
}

// MARK: - PlayerDelegate

/// Player delegate protocol
public protocol PlayerDelegate: NSObjectProtocol {
    func playerReady(_ player: Player)
    func playerPlaybackStateDidChange(_ player: Player)
    func playerBufferingStateDidChange(_ player: Player)
    
    //this is the time in seconds that the video has buffered to.  
    //If implementing a UIProgressView, user this value / player.maximumDuration to set progress.
    func playerBufferTimeDidChange(_ bufferTime: Double)
}


/// Player playback protocol
public protocol PlayerPlaybackDelegate: NSObjectProtocol {
    func playerCurrentTimeDidChange(_ player: Player)
    func playerPlaybackWillStartFromBeginning(_ player: Player)
    func playerPlaybackDidEnd(_ player: Player)
    func playerPlaybackWillLoop(_ player: Player)
}

// MARK: - Player

/// ▶️ Player, simple way to play and stream media
open class Player: UIViewController {

    /// Player delegate.
    open weak var playerDelegate: PlayerDelegate?
    
    /// Playback delegate.
    open weak var playbackDelegate: PlayerPlaybackDelegate?

    // configuration
    
    /// Local or remote URL for the file asset to be played.
    ///
    /// - Parameter url: URL of the asset.
    open var url: URL? {
        didSet {
            setup(url: url)
        }
    }

    /// For setting up with AVAsset instead of URL
    /// Note: Resets URL (cannot set both)
    open var asset: AVAsset? {
        didSet {
            url = nil
            guard isViewLoaded else { return }

            if let asset = asset {
                self.setupAsset(asset)
            }
        }
    }

    /// Mutes audio playback when true.
    open var muted: Bool {
        get {
            return self._avplayer.isMuted
        }
        set {
            self._avplayer.isMuted = newValue
        }
    }
    
    /// Volume for the player, ranging from 0.0 to 1.0 on a linear scale.
    open var volume: Float {
        get {
            return self._avplayer.volume
        }
        set {
            self._avplayer.volume = newValue
        }
    }

    /// Specifies how the video is displayed within a player layer’s bounds.
    /// The default value is `AVLayerVideoGravityResizeAspect`. See `FillMode` enum.
    open var fillMode: String {
        get {
            return self._playerView.fillMode
        }
        set {
            self._playerView.fillMode = newValue
        }
    }

    /// Pauses playback automatically when backgrounded.
    open var playbackPausesWhenBackgrounded: Bool
    
    /// Resumes playback when entering foreground.
    open var playbackResumesWhenEnteringForeground: Bool
    
    // state

    /// Playback automatically loops continuously when true.
    open var playbackLoops: Bool {
        get {
            return (self._avplayer.actionAtItemEnd == .none) as Bool
        }
        set {
            if newValue == true {
                self._avplayer.actionAtItemEnd = .none
            } else {
                self._avplayer.actionAtItemEnd = .pause
            }
        }
    }

    /// Playback freezes on last frame frame at end when true.
    open var playbackFreezesAtEnd: Bool = false

    /// Current playback state of the Player.
    open var playbackState: PlaybackState = .stopped {
        didSet {
            if playbackState != oldValue || !playbackEdgeTriggered {
                self.playerDelegate?.playerPlaybackStateDidChange(self)
            }
        }
    }
    
    /// Current buffering state of the Player.
    open var bufferingState: BufferingState = .unknown {
       didSet {
            if bufferingState != oldValue || !playbackEdgeTriggered {
                self.playerDelegate?.playerBufferingStateDidChange(self)
            }
        }
    }

    /// Playback buffering size in seconds.
    open var bufferSize: Double = 10
    
    /// Playback is not automatically triggered from state changes when true.
    open var playbackEdgeTriggered: Bool = true

    /// Maximum duration of playback.
    open var maximumDuration: TimeInterval {
        get {
            if let playerItem = self._playerItem {
                return CMTimeGetSeconds(playerItem.duration)
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }

    /// Media playback's current time.
    open var currentTime: TimeInterval {
        get {
            if let playerItem = self._playerItem {
                return CMTimeGetSeconds(playerItem.currentTime())
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }

    /// The natural dimensions of the media.
    open var naturalSize: CGSize {
        get {
            if let playerItem = self._playerItem {
                let track = playerItem.asset.tracks(withMediaType: AVMediaTypeVideo)[0]
                return track.naturalSize
            } else {
                return CGSize.zero
            }
        }
    }

    /// Player view's initial background color.
    open var layerBackgroundColor: UIColor? {
        get {
            guard let backgroundColor = self._playerView.playerLayer?.backgroundColor else { return nil }
            return UIColor(cgColor: backgroundColor)
        }
        set {
            self._playerView.playerLayer?.backgroundColor = newValue?.cgColor
        }
    }
    
    // MARK: - private instance vars
    
    internal var _asset: AVAsset!
    internal var _avplayer: AVPlayer
    internal var _playerItem: AVPlayerItem?
    internal var _playerView: PlayerView!
    internal var _timeObserver: Any!
    
    // MARK: - object lifecycle

    public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        self._avplayer = AVPlayer()
        self._avplayer.actionAtItemEnd = .pause
        self.playbackFreezesAtEnd = false
        self.playbackPausesWhenBackgrounded = true
        self.playbackResumesWhenEnteringForeground = true
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self._avplayer = AVPlayer()
        self._avplayer.actionAtItemEnd = .pause
        self.playbackFreezesAtEnd = false
        self.playbackPausesWhenBackgrounded = true
        self.playbackResumesWhenEnteringForeground = true
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    deinit {
        self.playerDelegate = nil
        self.removeApplicationObservers()
 
        self.playbackDelegate = nil
        self.removePlayerLayerObservers()
        self._playerView.player = nil
        
        self.removePlayerObservers()

        self._avplayer.pause()
        self.setupPlayerItem(nil)
    }

    // MARK: - view lifecycle

    open override func loadView() {
        self._playerView = PlayerView(frame: CGRect.zero)
        self._playerView.fillMode = AVLayerVideoGravityResizeAspect
        self._playerView.playerLayer?.isHidden = true
        self.view = self._playerView
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        if self.url != nil {
            setup(url: url)
        } else if let asset = self.asset {
            setupAsset(asset)
        }
        
        self.addPlayerLayerObservers();
        self.addPlayerObservers();
        self.addApplicationObservers();
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.playbackState == .playing {
            self.pause()
        }
    }
    
    // MARK: - Playback funcs

    /// Begins playback of the media from the beginning.
    open func playFromBeginning() {
        self.playbackDelegate?.playerPlaybackWillStartFromBeginning(self)
        self._avplayer.seek(to: kCMTimeZero)
        self.playFromCurrentTime()
    }

    /// Begins playback of the media from the current time.
    open func playFromCurrentTime() {
        self.playbackState = .playing
        self._avplayer.play()
    }

    /// Pauses playback of the media.
    open func pause() {
        if self.playbackState != .playing {
            return
        }

        self._avplayer.pause()
        self.playbackState = .paused
    }

    /// Stops playback of the media.
    open func stop() {
        if self.playbackState == .stopped {
            return
        }

        self._avplayer.pause()
        self.playbackState = .stopped
        self.playbackDelegate?.playerPlaybackDidEnd(self)
    }
    
    /// Updates playback to the specified time.
    ///
    /// - Parameter time: The time to switch to move the playback.
    open func seek(to time: CMTime) {
        if let playerItem = self._playerItem {
            return playerItem.seek(to: time)
        }
    }
    
    /// Updates playback to the specified time.
    ///
    /// - Parameters:
    ///   - time: The time to switch to move the playback.
    ///   - completionHandler: call block handler after seeking
    open func seek(to time: CMTime , completionHandler: @escaping () -> Swift.Void) {
        if let playerItem =  self._playerItem{
            return playerItem.seek(to: time, completionHandler: { (seeked) in
                completionHandler()
            })
        }
    }

    /// Updates the playback time to the specified time bound.
    ///
    /// - Parameters:
    ///   - time: The time to switch to move the playback.
    ///   - toleranceBefore: The tolerance allowed before time.
    ///   - toleranceAfter: The tolerance allowed after time.
    open func seekToTime(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) {
        if let playerItem = self._playerItem {
            return playerItem.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
        }
    }
    
    /// Captures a snapshot of the current Player view.
    ///
    /// - Returns: A UIImage of the player view.
    open func takeSnapshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self._playerView.frame.size, false, UIScreen.main.scale)
        self._playerView.drawHierarchy(in: self._playerView.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }

    /// Return the av player layer for consumption by
    /// things such as Picture in Picture
    open func playerLayer() -> AVPlayerLayer? {
        return self._playerView.playerLayer
    }
}

// MARK: - loading funcs

extension Player {
    
    fileprivate func setup(url: URL?) {
        guard isViewLoaded else { return }
        
        // ensure everything is reset beforehand
        if self.playbackState == .playing {
            self.pause()
        }
        
        self.setupPlayerItem(nil)
        
        if let url = url {
            let asset = AVURLAsset(url: url, options: .none)
            self.setupAsset(asset)
        }
    }

    fileprivate func setupAsset(_ asset: AVAsset) {
        if self.playbackState == .playing {
            self.pause()
        }

        self.bufferingState = .unknown

        self._asset = asset
        if let _ = self._asset {
            self.setupPlayerItem(nil)
        }

        let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]

        self._asset.loadValuesAsynchronously(forKeys: keys, completionHandler: { () -> Void in
            DispatchQueue.main.async(execute: { () -> Void in

                for key in keys {
                    var error: NSError?
                    let status = self._asset.statusOfValue(forKey: key, error:&error)
                    if status == .failed {
                        self.playbackState = .failed
                        return
                    }
                }

                if self._asset.isPlayable == false {
                    self.playbackState = .failed
                    return
                }

                let playerItem: AVPlayerItem = AVPlayerItem(asset:self._asset)
                self.setupPlayerItem(playerItem)

            })
        })
    }

    fileprivate func setupPlayerItem(_ playerItem: AVPlayerItem?) {
        if let currentPlayerItem = self._playerItem {
            currentPlayerItem.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
            currentPlayerItem.removeObserver(self, forKeyPath: PlayerKeepUpKey, context: &PlayerItemObserverContext)
            currentPlayerItem.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)
            currentPlayerItem.removeObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, context: &PlayerItemObserverContext)

            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentPlayerItem)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: currentPlayerItem)
        }

        self._playerItem = playerItem

        if let updatedPlayerItem = self._playerItem {
            updatedPlayerItem.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            updatedPlayerItem.addObserver(self, forKeyPath: PlayerKeepUpKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            updatedPlayerItem.addObserver(self, forKeyPath: PlayerStatusKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            updatedPlayerItem.addObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, options: ([.new, .old]), context: &PlayerItemObserverContext)

            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: updatedPlayerItem)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: updatedPlayerItem)
        }

        let playbackLoops = self.playbackLoops
        
        self._avplayer.replaceCurrentItem(with: self._playerItem)
        
        // update new playerItem settings
        if playbackLoops == true {
            self._avplayer.actionAtItemEnd = .none
        } else {
            self._avplayer.actionAtItemEnd = .pause
        }
    }

}

// MARK: - NSNotifications

extension Player {
    
    // AVPlayerItem
    
    internal func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        if self.playbackLoops == true {
            self.playbackDelegate?.playerPlaybackWillLoop(self)
            self._avplayer.seek(to: kCMTimeZero)
        } else {
            if self.playbackFreezesAtEnd == true {
                self.stop()
            } else {
                self._avplayer.seek(to: kCMTimeZero, completionHandler: { _ in
                    self.stop()
                })
            }
        }
    }

    internal func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        self.playbackState = .failed
    }
    
    // UIApplication
    
    internal func addApplicationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive(_:)), name: .UIApplicationWillResignActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object: UIApplication.shared)
    }
    
    internal func removeApplicationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    internal func handleApplicationWillResignActive(_ aNotification: Notification) {
        if self.playbackState == .playing {
            self.pause()
        }
    }

    internal func handleApplicationDidEnterBackground(_ aNotification: Notification) {
        if self.playbackState == .playing && self.playbackPausesWhenBackgrounded {
            self.pause()
        }
    }
  
    internal func handleApplicationWillEnterForeground(_ aNoticiation: Notification) {
        if self.playbackState != .playing && self.playbackResumesWhenEnteringForeground {
            self.playFromCurrentTime()
        }
    }

}

// MARK: - KVO

// KVO contexts

private var PlayerObserverContext = 0
private var PlayerItemObserverContext = 0
private var PlayerLayerObserverContext = 0

// KVO player keys

private let PlayerTracksKey = "tracks"
private let PlayerPlayableKey = "playable"
private let PlayerDurationKey = "duration"
private let PlayerRateKey = "rate"

// KVO player item keys

private let PlayerStatusKey = "status"
private let PlayerEmptyBufferKey = "playbackBufferEmpty"
private let PlayerKeepUpKey = "playbackLikelyToKeepUp"
private let PlayerLoadedTimeRangesKey = "loadedTimeRanges"

// KVO player layer keys

private let PlayerReadyForDisplayKey = "readyForDisplay"

extension Player {
    
    // MARK: - AVPlayerLayerObservers
    
    internal func addPlayerLayerObservers() {
        self._playerView.layer.addObserver(self, forKeyPath: PlayerReadyForDisplayKey, options: ([.new, .old]), context: &PlayerLayerObserverContext)
    }
    
    internal func removePlayerLayerObservers() {
        self._playerView.layer.removeObserver(self, forKeyPath: PlayerReadyForDisplayKey, context: &PlayerLayerObserverContext)
    }
    
    // MARK: - AVPlayerObservers
    
    internal func addPlayerObservers() {
        self._timeObserver = self._avplayer.addPeriodicTimeObserver(forInterval: CMTimeMake(1,100), queue: DispatchQueue.main, using: { [weak self] timeInterval in
            guard let strongSelf = self
            else {
                return
            }
            strongSelf.playbackDelegate?.playerCurrentTimeDidChange(strongSelf)
        })
        self._avplayer.addObserver(self, forKeyPath: PlayerRateKey, options: ([.new, .old]) , context: &PlayerObserverContext)
    }
    
    internal func removePlayerObservers() {
        self._avplayer.removeTimeObserver(_timeObserver)
        self._avplayer.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)
    }
    
    // MARK: -
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        // PlayerRateKey, PlayerObserverContext
        
        if (context == &PlayerItemObserverContext) {
            
            // PlayerStatusKey
            
            if keyPath == PlayerKeepUpKey {
                
                // PlayerKeepUpKey
                
                if let item = self._playerItem {
                    self.bufferingState = .ready
                    
                    if item.isPlaybackLikelyToKeepUp && self.playbackState == .playing {
                        self.playFromCurrentTime()
                    }
                }
                
                if let status = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    switch (status.intValue as AVPlayerStatus.RawValue) {
                    case AVPlayerStatus.readyToPlay.rawValue:
                        if let layer = self._playerView.playerLayer {
                            layer.player = self._avplayer
                            layer.isHidden = false
                        }
                        break
                    case AVPlayerStatus.failed.rawValue:
                        self.playbackState = PlaybackState.failed
                        break
                    default:
                        break
                    }
                }
                    
            } else if keyPath == PlayerEmptyBufferKey {
                
                // PlayerEmptyBufferKey
                
                if let item = self._playerItem {
                    if item.isPlaybackBufferEmpty {
                        self.bufferingState = .delayed
                    }
                }
                
                if let status = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    switch (status.intValue as AVPlayerStatus.RawValue) {
                    case AVPlayerStatus.readyToPlay.rawValue:
                        if let layer = self._playerView.playerLayer {
                            layer.player = self._avplayer
                            layer.isHidden = false
                        }
                        break
                    case AVPlayerStatus.failed.rawValue:
                        self.playbackState = PlaybackState.failed
                        break
                    default:
                        break
                    }
                }
                
            } else if keyPath == PlayerLoadedTimeRangesKey {
                
                // PlayerLoadedTimeRangesKey
                
                if let item = self._playerItem {
                    self.bufferingState = .ready
                    
                    let timeRanges = item.loadedTimeRanges
                    if let timeRange = timeRanges.first?.timeRangeValue {
                        let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timeRange.start, timeRange.duration))
                        self.playerDelegate?.playerBufferTimeDidChange(bufferedTime)
                        let currentTime = CMTimeGetSeconds(item.currentTime())
                        if (bufferedTime - currentTime) >= self.bufferSize && self.playbackState == .playing {
                            self.playFromCurrentTime()
                        }
                    } else {
                        self.playFromCurrentTime()
                    }
                }
            }
        
        } else if (context == &PlayerLayerObserverContext) {
            if let layer = self._playerView.playerLayer {
                if layer.isReadyForDisplay {
                    self.executeClosureOnMainQueueIfNecessary(withClosure: {
                        self.playerDelegate?.playerReady(self)
                    })
                }
            }
        }
        
    }

}

// MARK: - PlayerView

internal class PlayerView: UIView {

    override class var layerClass: Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }

    var playerLayer: AVPlayerLayer? {
        get {
            return self.layer as? AVPlayerLayer
        }
    }

    var player: AVPlayer? {
        get {
            return self.playerLayer?.player
        }
        set {
            if self.playerLayer?.player != newValue {
                self.playerLayer?.player = newValue
            }
        }
    }

    var fillMode: String {
        get {
            return self.playerLayer?.videoGravity ?? ""
        }
        set {
            self.playerLayer?.videoGravity = newValue
        }
    }
    
    // MARK: - object lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.playerLayer?.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.playerLayer?.backgroundColor = UIColor.black.cgColor
    }

}

// MARK: - queues

extension Player {
    
    internal func executeClosureOnMainQueueIfNecessary(withClosure closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async(execute: closure)
        }
    }
    
}
