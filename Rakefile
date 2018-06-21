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
            if system("which -s xcpretty")
                sh("/bin/sh", "-o", "pipefail", "-c", "env NSUnbufferedIO=YES xcodebuild -workspace Player.xcworkspace -scheme '#{scheme}' -xcconfig $XCCONFIG -configuration $CONFIG -sdk $SDK build analyze | xcpretty")
                else
                sh(cmd)
            end
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
