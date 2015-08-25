Pod::Spec.new do |s|

  s.name         = "DMImagePicker"
  s.version      = "0.0.4"
  s.summary      = "Custom image picker for ios."
  s.homepage     = "https://github.com/DimaAvvakumov/DMPopupAlert"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Dmitry Avvakumov" => "avvakumov@it-baker.ru" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/DimaAvvakumov/DMPopupAlert.git", :tag => "0.0.4" }
  s.source_files = "DMImagePicker", "DMImagePicker/*.{h,m,xib}", "DMImagePicker", "DMImagePicker/core/*.{h,m,xib}"
  s.public_header_files = "DMImagePicker/*.{h,m}"
  s.framework    = "UIKit"
  s.requires_arc = true
  s.resources    = 'DMImagePicker/DMImagePickerBundle.bundle'

end
