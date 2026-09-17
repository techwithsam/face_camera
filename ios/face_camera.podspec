#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint face_camera.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'face_camera'
  s.version          = '0.2.0'
  s.summary          = 'A Flutter camera plugin that detects faces in real-time.'
  s.description      = <<-DESC
A Flutter camera plugin that detects faces in real-time. Supports automatic
capture on face detection and is suitable for KYC / selfie flows.
                       DESC
  s.homepage         = 'https://github.com/Conezi/face_camera'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Conezi' => 'https://github.com/Conezi' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.9'
end
