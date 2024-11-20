
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gana/version"

Gem::Specification.new do |spec|
  spec.name          = "gana"
  spec.version       = Gana::VERSION
  spec.authors       = ["Vladimir Kochnev"]
  spec.email         = ["hashtable@yandex.ru"]

  spec.summary       = %q{Simulate concurrent database transactions}
  spec.homepage      = "https://github.com/marshall-lee/gana"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(spec)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", "~> 5.16"

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.10.0"
  spec.add_development_dependency "pg", "~> 1.2"
  spec.add_development_dependency "pry", "~> 0.13"
  spec.add_development_dependency "pry-byebug", "~> 3.9"
  spec.add_development_dependency "pry-doc", "~> 1.2"
  spec.add_development_dependency "curses", "~> 1.4"
end
