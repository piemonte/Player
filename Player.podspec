Pod::Spec.new do |s|
  s.name = 'Player'
  s.version = '0.0.1'
  s.license = 'MIT'
  s.summary = 'iOS video player in Swift'
  s.homepage = 'https://github.com/piemonte/player'
  s.social_media_url = 'http://twitter.com/piemonte'
  s.authors = { "Patrick Piemonte" => "piemonte@alumni.cmu.edu" }
  s.source = { :git => 'https://github.com/piemonte/player.git', :tag => '0.0.1' }
  s.ios.deployment_target = '8.0'
  s.source_files = 'Source/*.swift'
end
