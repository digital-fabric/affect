require_relative './lib/affect/version'

Gem::Specification.new do |s|
  s.name        = 'affect'
  s.version     = Affect::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Affect: Algebraic Effects for Ruby'
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = `git ls-files`.split
  s.homepage    = 'http://github.com/digital-fabric/affect'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/affect"
  }
  s.rdoc_options = ["--title", "affect", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
  s.require_paths = ["lib"]

  # s.add_runtime_dependency      'modulation',     '~>0.25'
  
  s.add_development_dependency  'minitest',       '5.11.3'
end
