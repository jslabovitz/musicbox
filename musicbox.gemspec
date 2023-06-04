#encoding: utf-8

Gem::Specification.new do |s|
  s.name          = 'musicbox'
  s.version       = '0.1'
  s.author        = 'John Labovitz'
  s.email         = 'johnl@johnlabovitz.com'

  s.summary       = %q{Album-based music catalog/player}
  s.description   = %q{An album-based music catalog/player.}
  s.homepage      = 'http://github.com/jslabovitz/musicbox'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_path  = 'lib'

  s.add_dependency 'autoeq_loader', '~> 0.1'
  s.add_dependency 'discogs-collection', '~> 0.1'
  s.add_dependency 'io-dispatcher', '~> 0.5'
  s.add_dependency 'iterm-show-image-file', '~> 0.1'
  s.add_dependency 'mime-types', '~> 3.4'
  s.add_dependency 'matrix'   # for prawn
  s.add_dependency 'mp4tags', '~> 0.1'
  s.add_dependency 'mpv_client', '~> 0.2'
  s.add_dependency 'path', '~> 2.1'
  s.add_dependency 'prawn', '~> 2.4'
  s.add_dependency 'run-command', '~> 0.4'
  s.add_dependency 'set_params', '~> 0.2'
  s.add_dependency 'simple-command', '~> 0.5'
  s.add_dependency 'simple-group', '~> 0.2'
  s.add_dependency 'simple-printer', '~> 0.1'
  s.add_dependency 'sixarm_ruby_unaccent', '~> 1.2'
  s.add_dependency 'tty-config', '~> 0.6'
  s.add_dependency 'tty-prompt', '~> 0.23'

  s.add_development_dependency 'bundler', '~> 2.4'
  s.add_development_dependency 'minitest', '~> 5.18'
  s.add_development_dependency 'minitest-power_assert', '~> 0.3'
  s.add_development_dependency 'rake', '~> 13.0'
end