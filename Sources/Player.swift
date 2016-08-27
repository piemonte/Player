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
    case Stopped = 0
    case Playing
    case Paused
    case Failed

    public var description: String {
        get {
            switch self {
            case Stopped:
                return "Stopped"
            case Playing:
                return "Playing"
            case Failed:
                return "Failed"
            case Paused:
                return "Paused"
            }
        }
    }
}

public enum BufferingState: Int, CustomStringConvertible {
    case Unknown = 0
    case Ready
    case Delayed

    public var description: String {
        get {
            switch self {
            case Unknown:
                return "Unknown"
            case Ready:
                return "Ready"
            case Delayed:
                return "Delayed"
            }
        }
    }
}

// MARK: - PlayerDelegate

@objc public protocol PlayerDelegate: NSObjectProtocol {
    func playerReady(player: Player)
    func playerPlaybackStateDidChange(player: Player)
    func playerBufferingStateDidChange(player: Player)
    func playerCurrentTimeDidChange(player: Player)

    func playerPlaybackWillStartFromBeginning(player: Player)
    func playerPlaybackDidEnd(player: Player)
    
    optional func playerWillComeThroughLoop(player: Player)
}

// MARK: - Player

public class Player: UIViewController {

    public weak var delegate: PlayerDelegate?

    public func setUrl(url: NSURL) {
        // Make sure everything is reset beforehand
        if(self.playbackState == .Playing){
            self.pause()
        }

        self.setupPlayerItem(nil)
        let asset = AVURLAsset(URL: url, options: .None)
        self.setupAsset(asset)
    }

    public var muted: Bool {
        get {
            return self.player.muted
        }
        set {
            self.player.muted = newValue
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

    public var playbackLoops: Bool {
        get {
            return (self.player.actionAtItemEnd == .None) as Bool
        }
        set {
            if newValue.boolValue {
                self.player.actionAtItemEnd = .None
            } else {
                self.player.actionAtItemEnd = .Pause
            }
        }
    }
    
    public var playbackFreezesAtEnd: Bool = false
    
    public var playbackState: PlaybackState = .Stopped {
        didSet {
            if playbackState != oldValue || !playbackEdgeTriggered {
                self.delegate?.playerPlaybackStateDidChange(self)
            }
        }
    }
    
    public var bufferingState: BufferingState = .Unknown {
        didSet {
            if bufferingState != oldValue || !playbackEdgeTriggered {
                self.delegate?.playerBufferingStateDidChange(self)
            }
        }
    }
    
    public var bufferSize: Double = 10
    public var playbackEdgeTriggered: Bool = true

    public var maximumDuration: NSTimeInterval {
        get {
            if let playerItem = self.playerItem {
                return CMTimeGetSeconds(playerItem.duration)
            } else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    public var currentTime: NSTimeInterval {
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
                let track = playerItem.asset.tracksWithMediaType(AVMediaTypeVideo)[0]
                return track.naturalSize
            } else {
                return CGSizeZero
            }
        }
    }

    // MARK: - private instance vars
    
    private var asset: AVAsset!
    internal var playerItem: AVPlayerItem?

    internal var player: AVPlayer!
    internal var playerView: PlayerView!
    internal var timeObserver: AnyObject!
    
    // MARK: - object lifecycle

    public convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }

    private func commonInit() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .Pause

        self.playbackLoops = false
        self.playbackFreezesAtEnd = false
    }

    deinit {
        self.player.removeTimeObserver(timeObserver)
        self.playerView?.player = nil
        self.delegate = nil

        NSNotificationCenter.defaultCenter().removeObserver(self)

        self.playerView?.layer.removeObserver(self, forKeyPath: PlayerReadyForDisplayKey, context: &PlayerLayerObserverContext)

        self.player.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)

        self.player.pause()

        self.setupPlayerItem(nil)
    }

    // MARK: - view lifecycle

    public override func loadView() {
        self.playerView = PlayerView(frame: CGRectZero)
        self.playerView.fillMode = AVLayerVideoGravityResizeAspect
        self.playerView.playerLayer.hidden = true
        self.view = self.playerView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.playerView.layer.addObserver(self, forKeyPath: PlayerReadyForDisplayKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerLayerObserverContext)

        self.player.addObserver(self, forKeyPath: PlayerRateKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]) , context: &PlayerObserverContext)
        
        self.timeObserver = self.player.addPeriodicTimeObserverForInterval(CMTimeMake(1, 100), queue: dispatch_get_main_queue()) { [weak self] timeInterval in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.playerCurrentTimeDidChange(strongSelf)
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: UIApplicationWillEnterForegroundNotification, object: UIApplication.sharedApplication())
    }

    public override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        if self.playbackState == .Playing {
            self.pause()
        }
    }

    // MARK: - functions

    public func playFromBeginning() {
        self.delegate?.playerPlaybackWillStartFromBeginning(self)
        self.player.seekToTime(kCMTimeZero)
        self.playFromCurrentTime()
    }

    public func playFromCurrentTime() {
        self.playbackState = .Playing
        self.player.play()
    }

    public func pause() {
        if self.playbackState != .Playing {
            return
        }

        self.player.pause()
        self.playbackState = .Paused
    }

    public func stop() {
        if self.playbackState == .Stopped {
            return
        }

        self.player.pause()
        self.playbackState = .Stopped
        self.delegate?.playerPlaybackDidEnd(self)
    }
    
    public func seekToTime(time: CMTime) {
        if let playerItem = self.playerItem {
            return playerItem.seekToTime(time)
        }
    }

    // MARK: - private

    private func setupAsset(asset: AVAsset) {
        if self.playbackState == .Playing {
            self.pause()
        }

        self.bufferingState = .Unknown

        self.asset = asset
        if let _ = self.asset {
            self.setupPlayerItem(nil)
        }

        let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]

        self.asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: { () -> Void in
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in

                for key in keys {
                    var error: NSError?
                    let status = self.asset.statusOfValueForKey(key, error:&error)
                    if status == .Failed {
                        self.playbackState = .Failed
                        return
                    }
                }

                if self.asset.playable.boolValue == false {
                    self.playbackState = .Failed
                    return
                }

                let playerItem: AVPlayerItem = AVPlayerItem(asset:self.asset)
                self.setupPlayerItem(playerItem)

            })
        })
    }

    private func setupPlayerItem(playerItem: AVPlayerItem?) {
        if self.playerItem != nil {
            self.playerItem?.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerKeepUpKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, context: &PlayerItemObserverContext)

            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }

        self.playerItem = playerItem

        if self.playerItem != nil {
            self.playerItem?.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerKeepUpKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerStatusKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerLoadedTimeRangesKey, options: ([NSKeyValueObservingOptions.New, NSKeyValueObservingOptions.Old]), context: &PlayerItemObserverContext)

          NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
          NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }

        self.player.replaceCurrentItemWithPlayerItem(self.playerItem)

        if self.playbackLoops.boolValue == true {
            self.player.actionAtItemEnd = .None
        } else {
            self.player.actionAtItemEnd = .Pause
        }
    }
}

// MARK: - NSNotifications

extension Player {
    
    public func playerItemDidPlayToEndTime(aNotification: NSNotification) {
        if self.playbackLoops.boolValue == true {
            self.delegate?.playerWillComeThroughLoop?(self)
            self.player.seekToTime(kCMTimeZero)
        } else {
            if self.playbackFreezesAtEnd.boolValue == true {
                self.stop()
            } else {
                self.player.seekToTime(kCMTimeZero, completionHandler: { _ in
                    self.stop()
                })
            }
        }
    }

    public func playerItemFailedToPlayToEndTime(aNotification: NSNotification) {
        self.playbackState = .Failed
    }

    public func applicationWillResignActive(aNotification: NSNotification) {
        if self.playbackState == .Playing {
            self.pause()
        }
    }

    public func applicationDidEnterBackground(aNotification: NSNotification) {
        if self.playbackState == .Playing {
            self.pause()
        }
    }
  
    public func applicationWillEnterForeground(aNoticiation: NSNotification) {
        if self.playbackState == .Paused {
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

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        switch (keyPath, context) {
        case (.Some(PlayerRateKey), &PlayerObserverContext):
            true
        case (.Some(PlayerStatusKey), &PlayerItemObserverContext):
            true
        case (.Some(PlayerKeepUpKey), &PlayerItemObserverContext):
            if let item = self.playerItem {
                self.bufferingState = .Ready

                if item.playbackLikelyToKeepUp && self.playbackState == .Playing {
                    self.playFromCurrentTime()
                }
            }

            let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue

            switch (status) {
            case AVPlayerStatus.ReadyToPlay.rawValue:
                self.playerView.player = self.player
                self.playerView.playerLayer.hidden = false
            case AVPlayerStatus.Failed.rawValue:
                self.playbackState = PlaybackState.Failed
            default:
                true
            }
        case (.Some(PlayerEmptyBufferKey), &PlayerItemObserverContext):
            if let item = self.playerItem {
                if item.playbackBufferEmpty {
                    self.bufferingState = .Delayed
                }
            }

            let status = (change?[NSKeyValueChangeNewKey] as! NSNumber).integerValue as AVPlayerStatus.RawValue

            switch (status) {
            case AVPlayerStatus.ReadyToPlay.rawValue:
                self.playerView.playerLayer.player = self.player
                self.playerView.playerLayer.hidden = false
            case AVPlayerStatus.Failed.rawValue:
                self.playbackState = PlaybackState.Failed
            default:
                true
            }
        case (.Some(PlayerLoadedTimeRangesKey), &PlayerItemObserverContext):
            guard let item = self.playerItem else {
                return
            }
            
            if self.playbackState != .Playing {
                return
            }
            
            self.bufferingState = .Ready
            
            let timerange = (change?[NSKeyValueChangeNewKey] as! NSArray)[0].CMTimeRangeValue
            let bufferedTime = CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration))
            let currentTime = CMTimeGetSeconds(item.currentTime())
            
            if bufferedTime - currentTime >= self.bufferSize {
                self.playFromCurrentTime()
            }
        case (.Some(PlayerReadyForDisplayKey), &PlayerLayerObserverContext):
            if self.playerView.playerLayer.readyForDisplay {
                self.delegate?.playerReady(self)
            }
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)

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

    override class func layerClass() -> AnyClass {
        return AVPlayerLayer.self
    }

    // MARK: - object lifecycle

    convenience init() {
        self.init(frame: CGRectZero)
        self.playerLayer.backgroundColor = UIColor.blackColor().CGColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.playerLayer.backgroundColor = UIColor.blackColor().CGColor
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

}
