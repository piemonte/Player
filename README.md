![Player](https://github.com/piemonte/Player/raw/master/Player.gif)

## Player

`Player` is a simple iOS video player library written in [Swift](https://developer.apple.com/swift/).

[![Build Status](https://travis-ci.org/piemonte/Player.svg?branch=master)](https://travis-ci.org/piemonte/Player) [![Pod Version](https://img.shields.io/cocoapods/v/Player.svg?style=flat)](http://cocoadocs.org/docsets/Player/)

- Looking for an obj-c video player? Check out [PBJVideoPlayer (obj-c)](https://github.com/piemonte/PBJVideoPlayer).
- Looking for a Swift camera library? Check out [Next Level](https://github.com/NextLevel/NextLevel).

### Features
- [x] plays local media or streams remote media over HTTP
- [x] customizable UI and user interaction
- [x] no size restrictions
- [x] orientation change support
- [x] simple API

# Quick Start

`Player` is available for installation using the Cocoa dependency manager [CocoaPods](http://cocoapods.org/).  Alternatively, you can simply copy the `Player.swift` file into your Xcode project.

## Xcode 8 & Swift 3

```ruby
# CocoaPods
pod "Player", "~> 0.2.0"

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end

# Carthage
github "piemonte/Player" ~> 0.2.0

# SwiftPM
let package = Package(
    dependencies: [
        .Package(url: "https://github.com/piemonte/Player", majorVersion: 0)
    ]
)
```

## Xcode 8 & Swift 2.3 or Xcode 7

```ruby
# CocoaPods
pod "Player", "~> 0.1.3"

# Carthage
github "piemonte/Player" ~> 0.1.3
```

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
let videoUrl: NSURL = // file or http url
self.player.setUrl(videoUrl)
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

* [Swift Evolution](https://github.com/apple/swift-evolution)
* [AV Foundation Programming Guide](https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)
* [Next Level](https://github.com/NextLevel/NextLevel/), rad media capture in Swift
* [PBJVision](https://github.com/piemonte/PBJVision), iOS camera engine, features touch-to-record video, slow motion video, and photo capture
* [PBJVideoPlayer](https://github.com/piemonte/PBJVideoPlayer), a simple iOS video player library, written in obj-c

## License

Player is available under the MIT license, see the [LICENSE](https://github.com/piemonte/player/blob/master/LICENSE) file for more information.

