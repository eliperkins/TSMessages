Pod::Spec.new do |s|
  s.name         = "TSMessages"
  s.version      = "0.10.0"
  s.summary      = "Easy to use and customizable messages/notifications for iOS à la Tweetbot."
  s.description  = <<-DESC
                    This framework provides an easy to use class to show little notification views on the top of the screen. (à la Tweetbot).
The notification moves from the top of the screen underneath the navigation bar and stays there for a few seconds, depending on the length of the displayed text. To dismiss a notification before the time runs out, the user can swipe it to the top or just tap it.
There are 4 different types already set up for you: Success, Error, Warning, Message.
                   DESC

  s.homepage     = "https://github.com/eliperkins/TSMessages/"

  s.license      = 'MIT'

  s.author       = { "Felix Krause" => "krausefx@gmail.com", "Eli Perkins" => "eli.j.perkins@gmail.com" }

  s.source       = { :git => "https://github.com/eliperkins/TSMessages.git", :tag => "#{s.version}"}

  s.platform     = :ios, '5.0'

  s.source_files = 'TSMessages/Classes/**/*.{h,m}', 'TSMessages/Views/**/*.{h,m}'

  s.resources = "TSMessages/Resources/**/*.{png,json}"

  s.requires_arc = true

  s.dependency 'HexColors'
  s.dependency 'FLKAutoLayout'
end
