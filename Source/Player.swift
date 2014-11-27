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

public enum PlaybackState: Int {
    case Stopped = 0
    case Playing
    case Paused
    case Failed
}

public enum BufferingState: Int {
    case Unknown = 0
    case Ready
    case Delayed
}

public protocol PlayerDelegate {
    func playerReady(player: Player)
    func playerPlaybackStateDidChange(player: Player)

    func playerPlaybackWillStartFromBeginning(player: Player)
    func playerPlaybackDidEnd(player: Player)
}

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
private let PlayerKeepUp = "playbackLikelyToKeepUp"

// KVO player layer keys

private let PlayerReadyForDisplay = "readyForDisplay"

// MARK: - Player

public class Player: UIViewController {

    var delegate: PlayerDelegate!
    
    public var path: NSString! {
        get {
            return self.asset.URL.absoluteString
        }
        set {
            let url: NSURL? = NSURL(string: newValue)
            if let asset: AVURLAsset? = AVURLAsset(URL: url, options: .None) {
                self.setupAsset(asset!)
            }
        }
    }
    
    public var fillMode: NSString! {
        get {
            return self.playerView.fillMode
        }
        set {
            self.playerView.fillMode = newValue
        }
    }
    
    public var playbackLoops: Bool! {
        get {
            return (self.player?.actionAtItemEnd == .None) as Bool
        }
        set {
            if newValue.boolValue {
                self.player?.actionAtItemEnd = .None
            } else {
                self.player?.actionAtItemEnd = .Pause
            }
        }
    }
    public var playbackFreezesAtEnd: Bool!
    public var playbackState: PlaybackState!
    public var bufferingState: BufferingState!

    public var maximumDuration: NSTimeInterval! {
        get {
            return CMTimeGetSeconds(self.playerItem.duration)
        }
    }

    private var asset: AVURLAsset!
    private var player: AVPlayer!
    private var playerItem: AVPlayerItem!
    private var playerView: PlayerView!

    // MARK: object lifecycle

    public override init() {
        super.init()
        self.playbackLoops = false
        self.playbackFreezesAtEnd = false
        self.playbackState = .Stopped
        self.bufferingState = .Unknown
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    deinit {
        self.playerView.player = nil
        self.delegate = nil
    
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        self.playerView.layer.removeObserver(self, forKeyPath: PlayerReadyForDisplay, context: &PlayerLayerObserverContext)
        
        self.player.removeObserver(self, forKeyPath: PlayerRateKey, context: &PlayerObserverContext)
        
        self.player.pause()
        
        self.playerItem = nil
    }
    
    // MARK: view lifecycle
    
    public override func loadView() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .Pause
        self.player.addObserver(self, forKeyPath: PlayerRateKey, options: (NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old) , context: &PlayerObserverContext)
        
        self.playerView = PlayerView(frame: CGRectZero)
        self.playerView.fillMode = AVLayerVideoGravityResizeAspect
        self.playerView.playerLayer.hidden = true
        self.view = self.playerView
        
        self.playerView.playerLayer.addObserver(self, forKeyPath: PlayerReadyForDisplay, options: (NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old), context: &PlayerLayerObserverContext)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationWillResignActive:", name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: UIApplication.sharedApplication())
    }
    
    public override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.playbackState == .Playing {
            self.pause()
        }
    }
    
    // MARK: methods

    public func playFromBeginning() {
        self.delegate.playerPlaybackWillStartFromBeginning(self)
        self.player.seekToTime(kCMTimeZero)
        self.playFromCurrentTime()
    }
    
    public func playFromCurrentTime() {
        self.playbackState = .Playing
        self.delegate.playerPlaybackStateDidChange(self)
        self.player.play()
    }
    
    public func pause() {
        if self.playbackState != .Playing {
            return
        }
    
        self.player.pause()
        self.playbackState = .Paused
        self.delegate.playerPlaybackStateDidChange(self)
    }
    
    public func stop() {
        if self.playbackState == .Stopped {
            return
        }
    
        self.player.pause()
        self.playbackState = .Stopped
        self.delegate.playerPlaybackStateDidChange(self)
    }

    private func setupAsset(asset: AVURLAsset) {
        if self.playbackState == .Playing {
            self.pause()
        }
        
        self.bufferingState = .Unknown
        self.asset = asset
        
        let keys: [String] = [PlayerTracksKey, PlayerPlayableKey, PlayerDurationKey]
    
        self.asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: { () -> Void in
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in

                for key in keys {
                    var error: NSError?
                    let status = self.asset.statusOfValueForKey(key, error:&error)
                    if status == .Failed {
                        self.playbackState = .Failed
                        self.delegate.playerPlaybackStateDidChange(self)
                        return
                    }
                }

                if self.asset.playable.boolValue == false {
                    self.playbackState = .Failed
                    self.delegate.playerPlaybackStateDidChange(self)
                    return
                }

                let playerItem: AVPlayerItem = AVPlayerItem(asset:self.asset)
                self.setupPlayerItem(playerItem)
                
            })
        })
    }
    
    private func setupPlayerItem(playerItem: AVPlayerItem?) {
        let item = playerItem
        
        if item != nil {
            self.playerItem?.removeObserver(self, forKeyPath: PlayerEmptyBufferKey, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerKeepUp, context: &PlayerItemObserverContext)
            self.playerItem?.removeObserver(self, forKeyPath: PlayerStatusKey, context: &PlayerItemObserverContext)

            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }
        
        self.playerItem = item
        
        if item != nil {
            self.playerItem?.addObserver(self, forKeyPath: PlayerEmptyBufferKey, options: (NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerKeepUp, options: (NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old), context: &PlayerItemObserverContext)
            self.playerItem?.addObserver(self, forKeyPath: PlayerStatusKey, options: (NSKeyValueObservingOptions.New | NSKeyValueObservingOptions.Old), context: &PlayerItemObserverContext)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidPlayToEndTime:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemFailedToPlayToEndTime:", name: AVPlayerItemFailedToPlayToEndTimeNotification, object: self.playerItem)
        }
        
        self.player.replaceCurrentItemWithPlayerItem(self.playerItem)
        
        if self.playbackLoops.boolValue == true {
            self.player.actionAtItemEnd = .None
        } else {
            self.player.actionAtItemEnd = .Pause
        }
    }
    
    // MARK: NSNotifications
    
    public func playerItemDidPlayToEndTime(aNotification: NSNotification) {
        if self.playbackLoops.boolValue || self.playbackFreezesAtEnd.boolValue {
            self.player.seekToTime(kCMTimeZero)
        }
    }
    
    public func playerItemFailedToPlayToEndTime(aNotification: NSNotification) {
        self.playbackState = .Failed
        self.delegate.playerPlaybackStateDidChange(self)
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

    // MARK: KVO

    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        switch (keyPath, context) {
            case (PlayerRateKey, &PlayerObserverContext):
                true
            case (PlayerStatusKey, &PlayerItemObserverContext):
                true
            case (PlayerKeepUp, &PlayerItemObserverContext):
                if self.playerItem.playbackLikelyToKeepUp && self.playbackState == .Playing {
                    self.playFromCurrentTime()
                }
                let status = (change[NSKeyValueChangeNewKey] as NSNumber).integerValue as AVPlayerStatus.RawValue
                switch (status) {
                    case AVPlayerStatus.ReadyToPlay.rawValue:
                        self.playerView.playerLayer.player = self.player
                        self.playerView.playerLayer.hidden = false
                    case AVPlayerStatus.Failed.rawValue:
                        self.playbackState = PlaybackState.Failed
                        self.delegate.playerPlaybackStateDidChange(self)
                    default:
                        true
                }
            case (PlayerEmptyBufferKey, &PlayerItemObserverContext):
                let status = (change[NSKeyValueChangeNewKey] as NSNumber).integerValue as AVPlayerStatus.RawValue
                switch (status) {
                    case AVPlayerStatus.ReadyToPlay.rawValue:
                        self.playerView.playerLayer.player = self.player
                        self.playerView.playerLayer.hidden = false
                    case AVPlayerStatus.Failed.rawValue:
                        self.playbackState = PlaybackState.Failed
                        self.delegate.playerPlaybackStateDidChange(self)
                    default:
                        true
                }
            case (PlayerReadyForDisplay, &PlayerLayerObserverContext):
                if self.playerView.playerLayer.readyForDisplay {
                    self.delegate.playerReady(self)
                }
            default:
                super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            
        }
        
    }

}

// MARK: - PlayerView

public class PlayerView: UIView {
    
    public var player: AVPlayer! {
        get {
            return (self.layer as AVPlayerLayer).player
        }
        set {
            (self.layer as AVPlayerLayer).player = newValue
        }
    }
    
    public var playerLayer: AVPlayerLayer! {
        get {
            return self.layer as AVPlayerLayer
        }
    }

    public var fillMode: NSString! {
        get {
            return (self.layer as AVPlayerLayer).videoGravity
        }
        set {
            (self.layer as AVPlayerLayer).videoGravity = newValue
        }
    }
    
    public override class func layerClass() -> AnyClass {
        return AVPlayerLayer.self
    }

    // MARK: object lifecycle

    public override init() {
        super.init()
        self.playerLayer.backgroundColor = UIColor.blackColor().CGColor!
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.playerLayer.backgroundColor = UIColor.blackColor().CGColor!
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
