//  ViewController.swift
//
//  Created by Chris Zielinski on 06/18/18.
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

import AppKit
import Player

class ViewController: NSViewController {
    internal var player = Player()

    // MARK: Object lifecycle

    deinit {
        player.view.removeFromSuperview()
        player.removeFromParentViewController()
    }

    override func loadView() {
        view = NSView()
        view.autoresizingMask = [.height, .width]
        view.setFrameSize(NSSize(width: 400 * (16.0 / 9), height: 400))
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        player.view.autoresizingMask = [.height, .width]
        player.view.frame = view.bounds

        player.add(to: self)

        // Optional
        player.playerDelegate = self
        // Optional
        player.playbackDelegate = self

        let uri = "https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7"
            + "/films/meet-iphone-x/iphone-x-meet-iphone-tpl-cc-us-20171129_1280x720h.mp4"
        player.url = URL(string: uri)
        player.playbackLoops = true
        player.fillMode = .resizeAspectFill
        player.controlsStyle = .floating
        player.playbackPausesWhenResigningActive = false
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        player.playFromBeginning()
    }
}

// MARK: - PlayerDelegate (optional)

extension ViewController: PlayerDelegate {
    func playerReady(player: Player) {}

    func playerPlaybackStateDidChange(player: Player) {}

    func playerBufferingStateDidChange(player: Player) {}

    func playerBufferTimeDidChange(bufferTime: Double) {}
}

// MARK: - PlayerPlaybackDelegate (optional)

extension ViewController: PlayerPlaybackDelegate {
    func playerCurrentTimeDidChange(player: Player) {}

    func playerPlaybackWillStartFromBeginning(player: Player) {}

    func playerPlaybackDidEnd(player: Player) {}

    func playerPlaybackWillLoop(player: Player) {}
}
