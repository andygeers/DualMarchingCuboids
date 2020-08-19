#
# Be sure to run `pod lib lint AdaptiveSkeletonClimbing.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AdaptiveSkeletonClimbing'
  s.version          = '0.1.0'
  s.summary          = 'Swift implementation of Adaptive Skeleton Climbing.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Adaptive Skeleton Climbing implementation in Swift based on the paper by Tim Postony, Tien-Tsin Wongz and Pheng-Ann Hengz. Allows for generating isosurfaces from voxel data. 
DESC

  s.homepage         = 'https://github.com/andygeers/AdaptiveSkeletonClimbing'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'Andy Geers'
  s.source           = { :git => 'https://github.com/andygeers/AdaptiveSkeletonClimbing.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/andygeers'

  s.ios.deployment_target = '10.0'

  s.source_files = 'AdaptiveSkeletonClimbing/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AdaptiveSkeletonClimbing' => ['AdaptiveSkeletonClimbing/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'Euclid', "~> 0.3.0"
  s.dependency 'SwiftGraph', "~> 3.0.0"
end
