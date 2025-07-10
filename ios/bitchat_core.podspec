#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'bitchat_core'
  s.version          = '1.0.0'
  s.summary          = 'Core bitchat protocol and Bluetooth mesh networking for Flutter'
  s.description      = <<-DESC
Core bitchat protocol and Bluetooth mesh networking for Flutter.
Provides BLE peripheral and central functionality compatible with bitchat Swift implementation.
                       DESC
  s.homepage         = 'https://github.com/your-org/0xchat-lite'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end 