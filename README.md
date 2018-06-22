# Player

[![Build Status](https://travis-ci.org/piemonte/Player.svg?branch=master)](https://travis-ci.org/piemonte/Player)
[![Platform](https://img.shields.io/cocoapods/p/Player.svg?style=flat)](http://cocoadocs.org/docsets/Player) 
[![Pod Version](https://img.shields.io/cocoapods/v/Player.svg?style=flat)](http://cocoadocs.org/docsets/Player/) 
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift Version](https://img.shields.io/badge/language-swift%204.1-brightgreen.svg)](https://developer.apple.com/swift) 
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/piemonte/Player/blob/master/LICENSE)

![Overview](https://github.com/chriszielinski/Player/raw/master/readme-assets/player.gif)

<p align="center"><b>Player is a simple cross-platform video player library written in Swift.</b>
<br>
<br>
⚠️ <b>Warning</b>: version 0.9 has breaking API changes. ⚠️</p>

### Looking for...
- An obj-c video player? Check out [PBJVideoPlayer (obj-c)](https://github.com/piemonte/PBJVideoPlayer).
- A Swift camera library? Check out [Next Level](https://github.com/NextLevel/NextLevel).

### Features
- [x] plays local media or streams remote media over HTTP
- [x] customizable UI and user interaction
- [x] optional system-supplied playback controls
- [x] no size restrictions
- [x] orientation change support
- [x] simple API

### I'm a ~~Rapper~~ Wrapper
- uses [`AVPlayerViewController`](https://developer.apple.com/documentation/avkit/avplayerviewcontroller) on iOS/tvOS platforms for system-supplied playback controls (See `usesSystemPlaybackControls`). Otherwise, an [`AVPlayerLayer`](https://developer.apple.com/documentation/avfoundation/avplayerlayer).
- uses [`AVPlayerView`](https://developer.apple.com/documentation/avkit/avplayerview) on the macOS platform.

## Installation
`Player` is available for installation using CocoaPods or Carthage.  Alternatively, you can simply copy the `Player.swift` file into your Xcode project.

### Using [CocoaPods](http://cocoapods.org/)

```ruby
pod "Player"
```

Need Swift 3? Use release `0.7.0`. **Note**: macOS and system-supplied playback controls not supported.

```ruby
pod "Player", "~> 0.7.0"
```

### Using [Carthage](https://github.com/Carthage/Carthage)

```ruby
github "piemonte/Player"
```

## Quick Start

The sample projects provide an example of how to integrate `Player`, otherwise you can follow these steps.

Create and add the `Player` to your view controller.

```swift
let player = Player()
// Optional
player.playerDelegate = self
// Optional
player.playbackDelegate = self
player.view.frame = view.bounds
player.add(to: self)
```

Provide the file path to the resource you would like to play locally or stream. Ensure you're including the file extension.

```swift
player.url = URL(string: "https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7/films/meet-iphone-x/iphone-x-meet-iphone-tpl-cc-us-20171129_1280x720h.mp4")
```

play/pause/chill 🏖️

```swift
player.playFromBeginning()
player.pause()
```

Adjust the fill mode for the video, if needed. Note: On iOS, this property is ignored if using system-supplied playback controls.

```swift
player.fillMode = .resizeAspectFit
```

The fill mode can be set to the following values:

`.resizeAspectFit` (default)
![.resizeAspectFit](https://github.com/chriszielinski/Player/raw/master/readme-assets/aspectFit.png)

`.resizeAspectFill`
![.resizeAspectFill](https://github.com/chriszielinski/Player/raw/master/readme-assets/aspectFill.png)

`.resizeStretch` (aka please don't. I mean look at that poor thing)
![.resizeStretch](https://github.com/chriszielinski/Player/raw/master/readme-assets/stretch.png)

Display video playback progress, if desired. Note, all delegate methods are optional.

```swift
extension ViewController: PlayerPlaybackDelegate {
    public func playerPlaybackWillStartFromBeginning(player: Player) {}
    
    public func playerPlaybackDidEnd(player: Player) {}
    
    public func playerCurrentTimeDidChange(player: Player) {
        let currentProgress = Float(player.currentTime / player.maximumDuration)
        progressView.setProgress(currentProgress, animated: true)
    }
    
    public func playerPlaybackWillLoop(player: Player) {
        progressView.setProgress(0.0, animated: false)
    }
}
```

## iOS & tvOS
On iOS/tvOS platforms, the player displays system-supplied playback controls by default. 

![iOS system-supplied controls](https://github.com/chriszielinski/Player/raw/master/readme-assets/ios-controls.png)

![tvOS system-supplied controls](https://github.com/chriszielinski/Player/raw/master/readme-assets/tvos-controls.png)

These are optional and can be disabled as follows:

```swift
...
// Need to set before calling `add(to:)`
player.usesSystemPlaybackControls = false
player.add(to: self)
```

## macOS
On the macOS platform, the player can display media controls. 

```swift
player.controlsStyle = .floating
```

The controls' style can be set to the following:

`.none`

`.inline` (default)
![Player](https://github.com/chriszielinski/Player/raw/master/readme-assets/inline.png)

`.minimal`
![Player](https://github.com/chriszielinski/Player/raw/master/readme-assets/minimal.png)

`.floating`
![Player](https://github.com/chriszielinski/Player/raw/master/readme-assets/floating.png)

## Documentation

You can find [the docs here](http://piemonte.github.io/Player/). Documentation is generated with [jazzy](https://github.com/realm/jazzy) and hosted on [GitHub-Pages](https://pages.github.com).

## Community

- Need help? Use [Stack Overflow](http://stackoverflow.com/questions/tagged/player-swift) with the tag 'player-swift'.
- Questions? Use [Stack Overflow](http://stackoverflow.com/questions/tagged/player-swift) with the tag 'player-swift'.
- Found a bug? Open an [issue](https://github.com/piemonte/player/issues).
- Feature idea? ~~Open an [issue](https://github.com/piemonte/player/issues).~~ Do it yourself & PR when done 😅 (or you can open an issue).
- Want to contribute? Submit a [pull request](https://github.com/piemonte/player/pulls).

## Used In

- [Cards](https://github.com/PaoloCuscela/Cards) — Awesome iOS 11 appstore cards written in Swift.

## Resources

* [Swift Evolution](https://github.com/apple/swift-evolution)
* [AV Foundation Programming Guide](https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)
* [Next Level](https://github.com/NextLevel/NextLevel/), rad media capture in Swift
* [PBJVision](https://github.com/piemonte/PBJVision), iOS camera engine, features touch-to-record video, slow motion video, and photo capture
* [PBJVideoPlayer](https://github.com/piemonte/PBJVideoPlayer), a simple iOS video player library, written in obj-c

## Contributors

- [Patrick Piemonte](https://github.com/piemonte) — Original author, iOS/tvOS platforms.
- [Chris Zielinski](https://github.com/chriszielinski) — macOS platform.

## License

Player is available under the MIT license, see the [LICENSE](https://github.com/piemonte/player/blob/master/LICENSE) file for more information.

