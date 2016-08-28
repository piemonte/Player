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

@objc public protocol PlayerDelegate: NSObjectProtocol {
    func playerReady(_ player: Player)
    func playerPlaybackStateDidChange(_ player: Player)
    func playerBufferingStateDidChange(_ player: Player)
    func playerCurrentTimeDidChange(_ player: Player)

    func playerPlaybackWillStartFromBeginning(_ player: Player)
    func playerPlaybackDidEnd(_ player: Player)

    func playerWillComeThroughLoop(_ player: Player)
}

// MARK: - Player

public class Player: UIViewController {

    public weak var delegate: PlayerDelegate?

    // configuration
    
    public func setUrl(_ url: URL) {
        // ensure everything is reset beforehand
        if self.playbackState == .playing {
            self.pause()
        }

        self.setupPlayerItem(nil)
        let asset = AVURLAsset(url: url, options: .none)
        self.setupAsset(asset)
    }

    public var muted: Bool {
        get {
            return self.player.isMuted
        }
        set {
            self.player.isMuted = newValue
        }
    }

    public var fillMode: String {
        get {
            return self.playerView.fillMode
        }
        set {
            self.playerView.fillMode = newValue
        }
    }
    
    // state

    public var playbackLoops: Bool {
        get {
            return (self.player.actionAtItemEnd == .none) as Bool
        }
        set {
            if newValue == true {
                self.player.actionAtItemEnd = .none
            } else {
                self.player.actionAtItemEnd = .pause
            }
        }
    }

    public var playbackFreezesAtEnd: Bool = false
    public var playbackState: PlaybackState = .stopped {
        didSet {
            if playbackState != oldValue || !playbackEdgeTriggered {
                self.delegate?.playerPlaybackStateDidChange(self)
            }
        }
    }
    public var bufferingState: BufferingState = .unknown {
       didSet {
            if bufferingState != oldValue || !playbackEdgeTriggered {
                self.delegate?.playerBufferingStateDidChange(self)
            }
        }
    }

    public var bufferSize: Double = 10
    public var playbackEdgeTriggered: Bool = true

    public var maximumDuration: TimeInterval {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.duration)
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    public var currentTime: TimeInterval {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.currentTime())
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }

    public var naturalSize: CGSize {
        get {
            if let playerItem = self.playerItem {
                let track = playerItem.asset.tracks(withMediaType: AVMediaTypeVideo)[0]
                return track.naturalSize
            } else {
                return CGSize.zero
            }
        }
    }
    
    // MARK: - private instance vars
    
    private var asset: AVAsset!
    internal var playerItem: AVPlayerItem?
    internal var player: AVPlayer!
    internal var playerView: PlayerView!
    internal var timeObserver: Any!
    
    // MARK: - object lifecycle

    public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }

    private func commonInit() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .pause
        
        self.playbackLoops = false
        self.playbackFreezesAtEnd = false
    }

    deinit {
        self.player.removeTimeObserver(timeObserver)
        self.playerView?.player = nil
        self.delegate = nil

        NotificationCenter.default.removeObserver(self)
        self.playerView?.layer.removeObserver(self, forKeyPath: PlayerReadyForDisplayKey, context: &PlayerLayerObserverContext)

        self.player.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)

        self.player.pause()
        self.setupPlayerItem(nil)
    }

    // MARK: - view lifecycle

    public override func loadView() {
        self.playerView = PlayerView(frame: CGRect.zero)
        self.playerView.fillMode = AVLayerVideoGravityResizeAspect
        self.playerView.playerLayer.isHidden = true
        self.view = self.playerView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.playerView.layer.addObserver(self, forKeyPath: PlayerReadyForDisplayKey, options: ([.new, .old]), context: &PlayerLayerObserverContext)
        self.timeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTimeMake(1,100), queue: DispatchQueue.main, using: { [weak self] timeInterval in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.playerCurrentTimeDidChange(strongSelf)
        })

        self.player.addObserver(self, forKeyPath: PlayerRateKey, options: ([.new, .old]) , context: &PlayerObserverContext)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: UIApplication.shared)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.playbackState == .playing {
            self.pause()
        }
    }

    // MARK: - functions

    public func playFromBeginning() {
        self.delegate?.playerPlaybackWillStartFromBeginning(self)
        self.player.seek(to: kCMTimeZero)
        self.playFromCurrentTime()
    }

    public func playFromCurrentTime() {
        self.playbackState = .playing
        self.player.play()
    }

    public func pause() {
        if self.playbackState != .playing {
            return
        }

        self.player.pause()
        self.playbackState = .paused
    }

    public func stop() {
        if self.playbackState == .stopped {
            return
        }

        self.player.pause()
        self.playbackState = .stopped
        self.delegate?.playerPlaybackDidEnd(self)
    }
    
    public func seekToTime(_ time: CMTime) {
        if let playerItem = self.playerItem {
            return playerItem.seek(to: time)
        }
    }

    // MARK: - private

    private func setupAsset(_ asset: AVAsset) {
        if self.playbackState == .playing {
            self.pause()
        }

        self.bufferingState = .unknown

        self.asset = asset
        if let _ = self.asset {
            self.setupPlayerItem(nil)
        }

        let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]

        self.asset.loadValuesAsynchronously(forKeys: keys, completionHandler: { () -> Void in
            DispatchQueue.main.sync(execute: { () -> Void in

                for key in keys {
                    var error: NSError?
                    let status = self.asset.statusOfValue(forKey: key, error:&error)
                    if status == .failed {
                        self.playbackState = .failed
                        return
                    }
                }

                if self.asset.isPlayable == false {
                    self.playbackState = .failed
                    return
                }

                let playerItem: AVPlayerItem = AVPlayerItem(asset:self.asset)
                self.setupPlayerItem(playerItem)

            })
        })
    }

    private func setupPlayerItem(_ playerItem: AVPlayerItem?) {
        if self.playerItem != nil {
            self.playerItem?.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerKeepUpKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, context: &PlayerItemObserverContext)

            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.playerItem)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.playerItem)
        }

        self.playerItem = playerItem

        if self.playerItem != nil {
            self.playerItem?.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerKeepUpKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerStatusKey, options: ([.new, .old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, options: ([.new, .old]), context: &PlayerItemObserverContext)

            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.playerItem)
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: self.playerItem)
        }

        self.player.replaceCurrentItem(with: self.playerItem)

        if self.playbackLoops == true {
            self.player.actionAtItemEnd = .none
        } else {
            self.player.actionAtItemEnd = .pause
        }
    }

}

// MARK: - NSNotifications

extension Player {
        
    public func playerItemDidPlayToEndTime(_ aNotification: Notification) {
        if self.playbackLoops == true {
            self.delegate?.playerWillComeThroughLoop(self)
            self.player.seek(to: kCMTimeZero)
        } else {
            if self.playbackFreezesAtEnd == true {
                self.stop()
            } else {
                self.player.seek(to: kCMTimeZero, completionHandler: { _ in
                    self.stop()
                })
            }
        }
    }

    public func playerItemFailedToPlayToEndTime(_ aNotification: Notification) {
        self.playbackState = .failed
    }

    public func applicationWillResignActive(_ aNotification: Notification) {
        if self.playbackState == .playing {
            self.pause()
        }
    }

    public func applicationDidEnterBackground(_ aNotification: Notification) {
        if self.playbackState == .playing {
            self.pause()
        }
    }
  
    public func applicationWillEnterForeground(_ aNoticiation: Notification) {
        if self.playbackState == .paused {
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
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        // PlayerRateKey, PlayerObserverContext
        
        if (context == &PlayerItemObserverContext) {
            // PlayerStatusKey
            
            if keyPath == PlayerKeepUpKey {
                // PlayerKeepUpKey
                
                if let item = self.playerItem {
                    self.bufferingState = .ready
                    
                    if item.isPlaybackLikelyToKeepUp && self.playbackState == .playing {
                        self.playFromCurrentTime()
                    }
                }
                
                let status = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).intValue as AVPlayerStatus.RawValue
                
                switch (status) {
                case AVPlayerStatus.readyToPlay.rawValue:
                    self.playerView.playerLayer.player = self.player
                    self.playerView.playerLayer.isHidden = false
                case AVPlayerStatus.failed.rawValue:
                    self.playbackState = PlaybackState.failed
                default:
                    break
                }
            } else if keyPath == PlayerEmptyBufferKey {
                // PlayerEmptyBufferKey
                
                if let item = self.playerItem {
                    if item.isPlaybackBufferEmpty {
                        self.bufferingState = .delayed
                    }
                }
                
                let status = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).intValue as AVPlayerStatus.RawValue
                
                switch (status) {
                case AVPlayerStatus.readyToPlay.rawValue:
                    self.playerView.playerLayer.player = self.player
                    self.playerView.playerLayer.isHidden = false
                case AVPlayerStatus.failed.rawValue:
                    self.playbackState = PlaybackState.failed
                default:
                    break
                }
            } else if keyPath == PlayerLoadedTimeRangesKey {
                // PlayerLoadedTimeRangesKey

                guard let item = self.playerItem else {
                    return
                }
                
                if self.playbackState != .playing {
                    return
                }
                
                self.bufferingState = .ready
                
                let timerange = (change?[NSKeyValueChangeNewKey] as! NSArray)[0].CMTimeRangeValue
                let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration))
                let currentTime = CMTimeGetSeconds(item.currentTime())
                
                if bufferedTime - currentTime >= self.bufferSize {
                    self.playFromCurrentTime()
                }
            }
        
        } else if (context == &PlayerLayerObserverContext) {
            if self.playerView.playerLayer.isReadyForDisplay {
                self.delegate?.playerReady(self)
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

}

// MARK: - PlayerView

internal class PlayerView: UIView {

    var player: AVPlayer! {
        get {
            return (self.layer as! AVPlayerLayer).player
        }
        set {
            if (self.layer as! AVPlayerLayer).player != newValue {
                (self.layer as! AVPlayerLayer).player = newValue
            }
        }
    }

    var playerLayer: AVPlayerLayer {
        get {
            return self.layer as! AVPlayerLayer
        }
    }

    var fillMode: String {
        get {
            return (self.layer as! AVPlayerLayer).videoGravity
        }
        set {
            (self.layer as! AVPlayerLayer).videoGravity = newValue
        }
    }
    
    override class var layerClass: Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }

    // MARK: - object lifecycle

    convenience init() {
        self.init(frame: CGRect.zero)
        self.playerLayer.backgroundColor = UIColor.black.cgColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

}
