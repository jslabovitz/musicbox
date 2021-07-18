#encoding: utf-8

require_relative 'lib/musicbox/version'

Gem::Specification.new do |s|
  s.name          = 'musicbox'
  s.version       = MusicBox::VERSION
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

  s.add_dependency 'discogs-wrapper', '~> 2.5'
  s.add_dependency 'http', '~> 5.0'
  s.add_dependency 'io-dispatcher', '~> 0.1'
  s.add_dependency 'json', '~> 2.2'
  s.add_dependency 'mime-types', '~> 3.3'
  s.add_dependency 'mpv_client', '~> 0.1'
  s.add_dependency 'path', '~> 2.0'
  s.add_dependency 'prawn', '~> 2.2'
  s.add_dependency 'run-command', '~> 0.1'
  s.add_dependency 'set_params', '~> 0.1'
  s.add_dependency 'simple-command', '~> 0.2'
  s.add_dependency 'sixarm_ruby_unaccent', '~> 1.2'
  s.add_dependency 'tty-prompt', '~> 0.23'

  s.add_development_dependency 'bundler', '~> 2.2'
  s.add_development_dependency 'minitest', '~> 5.14'
  s.add_development_dependency 'minitest-power_assert', '~> 0.3'
  s.add_development_dependency 'rake', '~> 13.0'
end