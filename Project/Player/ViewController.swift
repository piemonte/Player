//  ViewController.swift
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
import Player

class ViewController: UIViewController {
    fileprivate var player = Player()

    // MARK: object lifecycle

    deinit {
        player.willMove(toParentViewController: self)
        player.view.removeFromSuperview()
        player.removeFromParentViewController()
    }

    // MARK: view lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        player.playerDelegate = self
        player.playbackDelegate = self
        player.view.translatesAutoresizingMaskIntoConstraints = false

        player.add(to: self)

        let uri = "https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7"
            + "/films/meet-iphone-x/iphone-x-meet-iphone-tpl-cc-us-20171129_1280x720h.mp4"
        player.url = URL(string: uri)

        player.playbackLoops = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                          action: #selector(handleTapGestureRecognizer(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        player.view.addGestureRecognizer(tapGestureRecognizer)

        NSLayoutConstraint.activate([
            player.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            player.view.topAnchor.constraint(equalTo: view.topAnchor),
            player.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            player.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(orientationWillChange),
                                               name: .UIDeviceOrientationDidChange, object: nil)

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: .UIDeviceOrientationDidChange, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        player.playFromBeginning()
    }

    @objc private func orientationWillChange() {
        let currentOrientation = UIDevice.current.orientation
        if UIDeviceOrientationIsLandscape(currentOrientation) {
            player.fillMode = .resizeAspectFill
        } else if UIDeviceOrientationIsPortrait(currentOrientation) {
            player.fillMode = .resizeAspectFit
        }
    }

}

// MARK: - UIGestureRecognizer

extension ViewController {
    @objc func handleTapGestureRecognizer(_ gestureRecognizer: UITapGestureRecognizer) {
        switch player.playbackState.rawValue {
        case PlaybackState.stopped.rawValue:
            player.playFromBeginning()
        case PlaybackState.paused.rawValue:
            player.playFromCurrentTime()
        case PlaybackState.playing.rawValue:
            player.pause()
        case PlaybackState.failed.rawValue:
            player.pause()
        default:
            player.pause()
        }
    }
}

// MARK: - PlayerDelegate

extension ViewController: PlayerDelegate {
    func playerReady(player: Player) {}

    func playerPlaybackStateDidChange(player: Player) {}

    func playerBufferingStateDidChange(player: Player) {}

    func playerBufferTimeDidChange(bufferTime: Double) {}
}

// MARK: - PlayerPlaybackDelegate

extension ViewController: PlayerPlaybackDelegate {
    func playerCurrentTimeDidChange(player: Player) {}

    func playerPlaybackWillStartFromBeginning(player: Player) {}

    func playerPlaybackDidEnd(player: Player) {}

    func playerPlaybackWillLoop(player: Player) {}
}
