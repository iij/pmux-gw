# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pmux-gw/version'

Gem::Specification.new do |gem|
  gem.name          = "pmux-gw"
  gem.version       = Pmux::Gateway::VERSION
  gem.authors       = ["Hiroyuki Kakine"]
  gem.email         = ["kakine@iij.ad.jp"]
  gem.description   = %q{Pmux gateway is an executor for Pmux through HTTP request}
  gem.summary       = %q{Pmux gateway server}
  gem.homepage      = "https://github.com/iij/pmux-gw"

  gem.files         = `find . -maxdepth 1 -name '.gitignore' -prune -o -type f -print; find {bin,lib,examples,rpm} -name '.svn' -prune -o -type f -print`.split().map{ |f| f.strip().sub("./", "") }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency('gflocator', '>= 0.0.1')
  gem.add_dependency('pmux', '>= 0.1.1')
  gem.add_dependency('eventmachine', '~> 1.0')
  gem.add_dependency('em_pessimistic', '>= 0.1.2')
  gem.add_dependency('eventmachine_httpserver', '>= 0.2.1')
  gem.add_development_dependency "bundler", ">= 1.2.1"
  gem.add_development_dependency "rake"
end
