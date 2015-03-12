![Player](https://github.com/piemonte/Player/raw/master/Player.gif)

## Player

`Player` is a simple iOS video player library written in [Swift](https://developer.apple.com/swift/).

### Features
- [x] plays local media or streams remote media over HTTP
- [x] customizable UI and user interaction
- [x] no size restrictions
- [x] orientation change support
- [x] simple API

If you're looking for a video player library written in Objective-C, checkout [PBJVideoPlayer](https://github.com/piemonte/PBJVideoPlayer). For video recording, checkout [PBJVision](https://github.com/piemonte/PBJVision).

[![Build Status](https://travis-ci.org/piemonte/Player.svg?branch=master)](https://travis-ci.org/piemonte/Player)
[![Pod Version](https://img.shields.io/cocoapods/v/Player.svg?style=flat)](http://cocoadocs.org/docsets/Player/)

Xcode 6.3 and Swift 1.2 support can be found on a [branch](https://github.com/piemonte/Player/tree/xcode-6.3).

## Installation

### CocoaPods

`Player` is available and recommended for installation using the Cocoa dependency manager [CocoaPods](http://cocoapods.org/). CocoaPods is still adding support for Swift, so a [pre-release](http://blog.cocoapods.org/Pod-Authors-Guide-to-CocoaPods-Frameworks/) version is required.

To integrate, just add the following line in your `Podfile`:

```ruby
pod ‘Player’
```	

### Carthage

Installation is also available using the dependency manager [Carthage](https://github.com/Carthage/Carthage).

To integrate, add the following line to your `Cartfile`:

```ogdl
github “piemonte/Player” >= 0.0.1
```

### Manual

You can also simply copy the `Player.swift` file into your Xcode project.

## Usage

The sample project provides an example of how to integrate `Player`, otherwise you can follow these steps.

Allocate and add the `Player` controller to your view hierarchy.

``` Swift
 self.player = Player()
 self.player.delegate = self
 self.player.view.frame = self.view.bounds
    
 self.addChildViewController(self.player)
 self.view.addSubview(self.player.view)
 self.player.didMoveToParentViewController(self)
```

Provide the file path to the resource you would like to play locally or stream. Ensure you're including the file extension.

``` Swift
 self.player.path = "Video.mp4"
```

play/pause/chill

``` Swift
 self.player.playFromBeginning()
```

Adjust the fill mode for the video, if needed.

``` Swift
 self.player.fillMode = “AVLayerVideoGravityResizeAspect”
```

## Community

- Need help? Use [Stack Overflow](http://stackoverflow.com/questions/tagged/player-swift) with the tag 'player-swift'.
- Questions? Use [Stack Overflow](http://stackoverflow.com/questions/tagged/player-swift) with the tag 'player-swift'.
- Found a bug? Open an [issue](https://github.com/piemonte/player/issues).
- Feature idea? Open an [issue](https://github.com/piemonte/player/issues).
- Want to contribute? Submit a [pull request](https://github.com/piemonte/player/pulls).

## Resources

* [AV Foundation Programming Guide](https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)
* [PBJVision, iOS camera engine, features touch-to-record video, slow motion video, and photo capture](https://github.com/piemonte/PBJVision)
* [PBJVideoPlayer, a simple iOS video player library, written in Objective-C](https://github.com/piemonte/PBJVideoPlayer)
* [objc.io Issue #16, Swift](http://www.objc.io/issue-16/)

## License

Player is available under the MIT license, see the [LICENSE](https://github.com/piemonte/player/blob/master/LICENSE) file for more information.

