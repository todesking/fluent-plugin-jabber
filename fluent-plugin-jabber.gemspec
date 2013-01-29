Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-jabber"
  gem.version       = "0.1.1"
  gem.authors       = ["todesking"]
  gem.email         = ["discommunicative@gmail.com"]
  gem.summary       = %q{Fluentd output plugin for XMPP(Jabber) protocol}
  gem.homepage      = "https://github.com/todesking/fluent-plugin-jabber"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"

  gem.add_runtime_dependency "xmpp4r"
  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency "pit"
end
