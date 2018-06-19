Pod::Spec.new do |s|
  s.name = 'Player'
  s.version = '0.8.4'
  s.license = 'MIT'
  s.summary = 'video player in Swift, simple way to play and stream media in your iOS/tvOS/macOS app'
  s.homepage = 'https://github.com/chriszielinski/player'
  s.social_media_url = 'https://twitter.com/mightbesuperman'
  s.authors = { 'patrick piemonte' => "piemonte@alumni.cmu.edu", 'chris zielinski' => "chrisz@berkeley.edu" }
  s.source = { :git => 'https://github.com/chriszielinski/player.git', :tag => s.version }
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.macos.deployment_target = '10.10'
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
  s.swift_version = '4.0'
#  s.screenshot = "https://raw.github.com/piemonte/Player/master/Player.gif"
end
