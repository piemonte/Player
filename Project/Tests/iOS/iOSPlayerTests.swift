//
//  iOSPlayerTests.swift
//  iOS  PlayerTests
//
//  Created by Chris Zielinski on 6/22/18.
//  Copyright © 2018 Patrick Piemonte. All rights reserved.
//

import XCTest
import Player
@testable import Player_iOS

class TestViewController: UIViewController {

    let player = Player()
    @objc dynamic var didLoop: Bool = false

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        player.url = Bundle(for: type(of: self)).url(forResource: "test", withExtension: "mp4")!
        player.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        player.view.frame = view.bounds

        player.playbackDelegate = self
    }
}

extension TestViewController: PlayerPlaybackDelegate {
    func playerPlaybackWillLoop(player: Player) {
        didLoop = true
    }
}

class iOSPlayerTests: XCTestCase {
    
    var testViewController: TestViewController!
    var player: Player {
        return testViewController.player
    }

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        testViewController = TestViewController()
        UIApplication.shared.windows.first!.rootViewController = testViewController
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        testViewController = nil
    }

    func testAutoplayEnabled() {
        player.autoplay = true
        player.add(to: testViewController)

        expectation(for: NSPredicate(format: "isPlaying == true"), evaluatedWith: player, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }

    func testAutoplayDisabled() {
        player.autoplay = false
        player.add(to: testViewController)

        let result = XCTWaiter.wait(for: [
            expectation(for: NSPredicate(format: "isPlaying == true"), evaluatedWith: player, handler: nil)],
                                    timeout: 5)
        XCTAssert(result == .timedOut)
    }

    func testPlaybackLoops() {
        player.playbackLoops = true
        player.add(to: testViewController)

        let result = XCTWaiter.wait(for: [
            expectation(for: NSPredicate(format: "didLoop == true"), evaluatedWith: testViewController, handler: nil)],
                                    timeout: 10)

        XCTAssert(result == .completed, "`playerPlaybackWillLoop(player:)` was not called.")
        XCTAssert(player.currentTime < 0.5, "Player did not loop.")
    }

    func testPlaybackFreezesAtEnd() {
        player.playbackFreezesAtEnd = true
        player.add(to: testViewController)

        let didNotLoop = expectation(for: NSPredicate(format: "didLoop == true"), evaluatedWith: testViewController, handler: nil)
        let result = XCTWaiter.wait(for: [didNotLoop], timeout: 5)

        XCTAssert(result == .timedOut, "`playerPlaybackWillLoop(player:)` was called.")
        XCTAssert(player.currentTime == player.maximumDuration, "Player did not freeze at last frame.")
        XCTAssert(!player.isPlaying, "`isPlaying` is true.")
    }
    
}
