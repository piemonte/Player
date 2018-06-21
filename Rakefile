# Based on the Regex Rakefile (https://github.com/sharplet/Regex)

namespace :build do
  desc "Build and validate the podspec"
  task :pod do
    sh "pod lib lint *.podspec --no-clean"
  end

  namespace :carthage do
    %w[ios macos tvos.each do |platform|
      desc "Build the Carthage framework on #{platform}"
      task platform.downcase.to_sym do
        sh "carthage build --platform #{platform} --no-skip-current"
      end
    end
  end

    namespace :xcodebuild do
        def pretty(cmd)
            if system("which -s xcpretty")
                sh("/bin/sh", "-o", "pipefail", "-c", "env NSUnbufferedIO=YES #{cmd} | xcpretty")
                else
                sh(cmd)
            end
        end

        desc "Build for macOS"
        task :macos do
            pretty "xcodebuild -workspace Player.xcworkspace -scheme 'Release - macOS' -configuration $CONFIG -sdk $SDK build analyze"
        end

        desc "Build for iOS "
        task :ios do
            pretty "xcodebuild -workspace Player.xcworkspace -scheme 'Release - iOS' -configuration $CONFIG -sdk $SDK build analyze"
        end

        desc "Build for tvOS"
        task :tvos do
            pretty "xcodebuild -workspace Player.xcworkspace -scheme 'Release - tvOS' -configuration $CONFIG -sdk $SDK build analyze"
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
