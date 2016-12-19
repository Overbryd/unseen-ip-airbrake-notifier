Gem::Specification.new do |s|
  s.name        = "unseen-ip-to-airbrake"
  s.version     = "1.0.0"
  s.date        = "2016-12-19"
  s.summary     = "Unseen IP to Airbrake"
  s.description = "Capture unseen IP addresses connection attempts and report them to Airbrake"
  s.authors     = ["Lukas Rieder"]
  s.email       = "l.rieder@gmail.com"
  s.files       = Dir.glob("{lib,bin}/**/*")
  s.bindir      = "bin"
  s.executables = Dir.glob("bin/*").map(&File.method(:basename))
  s.homepage    = "https://github.com/Overbryd/unseen-ip-to-airbrake"
  s.license     = "MIT"

  s.add_runtime_dependency "airbrake-ruby", "~> 1.6", ">= 1.6.0"
  s.add_development_dependency "rspec", "~> 3.5"
  s.add_development_dependency "timecop"
  s.add_development_dependency "pry-byebug"
end

