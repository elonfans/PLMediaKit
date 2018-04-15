Pod::Spec.new do |s|
  s.name         = "PLMediaPickerView"
  s.version      = "1.0.0"
  s.author       = { "pauleyliu" => "pauleyliu@gmail.com" }
  s.source       = { :git => "git@git.moumentei.com:paulery/PLMediaPickerView.git"}
  s.platform     = :ios, '8.0'
  s.homepage     = "http://git.moumentei.com/paulery/PLMediaPickerView"
  s.summary      = "A short description of PLMediaPickerView."
  s.requires_arc = true
  s.source_files = 'Source/Objective-C/PLMediaPickerView/**/*.{h,m}'
  s.resources    = "Source/Objective-C/PLMediaPickerView/**/*.{xib,bundle}"
end
