require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "SystemSpeechOutput"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package["description"]
  s.homepage     = package["homepage"]
  s.license      = { :type => "MIT" }
  s.author       = package["author"]
  s.platforms    = { :ios => "16.0" }
  s.source       = { :path => "." }
  s.source_files = "ios/**/*.{h,m,mm}"

  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"
  end
end
