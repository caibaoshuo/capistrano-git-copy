# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/git_copy/version'

Gem::Specification.new do |spec|
  spec.name          = 'capistrano-git-copy'
  spec.version       = Capistrano::GitCopy::VERSION
  spec.authors       = ['Florian Schwab']
  spec.email         = ['me@ydkn.de']
  spec.description   = 'Copy local git repository deploy strategy for capistrano.'
  spec.summary       = 'Copy local git repository deploy strategy for capistrano.'
  spec.homepage      = 'https://gitlab.com/ydkn/capistrano-git-copy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split("\n") + %w[vendor/git-archive-all/git_archive_all.py]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '>= 3.7.0', '< 4.0.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
end
