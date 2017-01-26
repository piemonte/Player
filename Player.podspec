Pod::Spec.new do |s|
  s.name = 'Player'
  s.version = '0.4.0'
  s.license = 'MIT'
  s.summary = 'video player in Swift, simple way to play and stream media in your iOS or tvOS app'
  s.homepage = 'https://github.com/piemonte/player'
  s.social_media_url = 'http://twitter.com/piemonte'
  s.authors = { 'patrick piemonte' => "piemonte@alumni.cmu.edu" }
  s.source = { :git => 'https://github.com/piemonte/player.git', :tag => s.version }
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.source_files = 'Sources/*.swift'
  s.requires_arc = true
#  s.screenshot = "https://raw.github.com/piemonte/Player/master/Player.gif"
end
