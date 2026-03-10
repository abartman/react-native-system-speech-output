require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "SystemSpeechOutput"
  s.version      = package["version"]
  s.summary      = "React Native system text-to-speech bridge"
  s.homepage     = "https://github.com/abartman/react-native-system-speech-output"
  s.license      = { :type => "MIT" }
  s.authors      = { "Adam Bartman" => "opensource@3sense.ai" }
  s.platforms    = { :ios => "16.0" }
  s.source       = { :path => "." }
  s.source_files = "ios/**/*.{h,m,mm}"
  s.frameworks   = "AVFoundation"

  s.dependency "React-Core"
end
