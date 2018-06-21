Pod::Spec.new do |s|
  s.name = 'Player'
  s.version = '0.9'
  s.license = 'MIT'
  s.summary = '▶️ A Swift Video Player: A simple way to play and stream media on iOS/tvOS/macOS'
  s.homepage = 'https://github.com/piemonte/player'
  s.social_media_url = 'https://twitter.com/piemonte'
  s.authors = { 'patrick piemonte' => "piemonte@alumni.cmu.edu", 'chris zielinski' => "chrisz@berkeley.edu" }
  s.source = { :git => 'https://github.com/piemonte/player.git', :tag => s.version }
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
  s.swift_version = '4.1'
#  s.screenshot = "https://raw.github.com/piemonte/Player/master/Player.gif"
end
