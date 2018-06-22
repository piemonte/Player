# Based on the Regex Rakefile (https://github.com/sharplet/Regex)

namespace :build do
    desc "Build and validate the podspec"
    task :pod do
    sh "pod lib lint *.podspec --no-clean"
    end

    desc "Build the Carthage frameworks for all platforms"
    task :carthage do
      sh "carthage build --no-skip-current"
    end

    namespace :xcodebuild do
        def pretty(scheme)
            sh("/bin/sh", "-o", "pipefail", "-c", "env NSUnbufferedIO=YES xcodebuild -workspace Player.xcworkspace -scheme '#{scheme}' -xcconfig $XCCONFIG -configuration $CONFIG -sdk $SDK build analyze | xcpretty")
        end

        desc "Build for macOS"
        task :macos do
            pretty "Release - macOS"
        end

        desc "Build for iOS "
        task :ios do
            pretty "Release - iOS"
        end

        desc "Build for tvOS"
        task :tvos do
            pretty "Release - tvOS"
        end
    end
end

namespace :test do
    def prettyTest(cmd)
        sh("/bin/sh", "-o", "pipefail", "-c", "env NSUnbufferedIO=YES xcodebuild build-for-testing test-without-building -workspace Player.xcworkspace -scheme #{cmd} -xcconfig $XCCONFIG -sdk $SDK | xcpretty")
    end

    desc "Run tests on macOS"
    task :macos do
        prettyTest "'Debug - macOS'"
    end

    desc "Run tests on iOS"
    task :ios do
        prettyTest "'Debug - iOS' -destination 'platform=iOS Simulator,name=iPhone X'"
    end

    desc "Run tests on tvOS"
    task :tvos do
        prettyTest "'Debug - tvOS' -destination 'platform=tvOS Simulator,name=Apple TV'"
    end
end

desc "Run swiftlint if available"
task :swiftlint do
  return unless system "which -s swiftlint"
  exec "swiftlint lint --reporter emoji"
end

desc "Clean built products"
task :clean do
  Dir["build/", "Carthage/Build/*/Player.framework*"].each do |f|
    rm_rf(f)
  end
end

desc "Build all platforms and run SwiftLint"
task :everything => ["build:xcodebuild:macos", "build:xcodebuild:ios", "build:xcodebuild:tvos", "swiftlint"]

task :default => :everything
