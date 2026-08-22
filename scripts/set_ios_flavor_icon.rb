#!/usr/bin/env ruby
# Points a flavor's Xcode configs at its generated app icon asset catalog.
#
# Run this AFTER `dart run flutter_launcher_icons` has generated
# ios/Runner/Assets.xcassets/AppIcon-<flavor>.appiconset/ (via a
# flutter_launcher_icons-<flavor>.yaml config at the repo root — see its
# "Flavor support" section). flutter_launcher_icons can't wire the
# ASSETCATALOG_COMPILER_APPICON_NAME build setting itself here because it
# looks for flavor-suffixed *.xcconfig filenames, and add_ios_flavor.rb
# deliberately shares the base Debug/Release xcconfig files across flavors
# (avoids extra CocoaPods per-flavor xcconfig wiring).
#
# Usage: ruby scripts/set_ios_flavor_icon.rb <flavor>
#   ruby scripts/set_ios_flavor_icon.rb myneedmart

require 'xcodeproj'

flavor = ARGV[0]
if flavor.nil?
  warn 'Usage: set_ios_flavor_icon.rb <flavor>'
  exit 1
end

catalog = "AppIcon-#{flavor}"
appiconset = File.expand_path("../ios/Runner/Assets.xcassets/#{catalog}.appiconset", __dir__)
unless Dir.exist?(appiconset)
  warn "#{appiconset} doesn't exist yet — generate it first with " \
       "`dart run flutter_launcher_icons` (needs flutter_launcher_icons-#{flavor}.yaml)."
  exit 1
end

project = Xcodeproj::Project.open(File.expand_path('../ios/Runner.xcodeproj', __dir__))
runner = project.targets.find { |t| t.name == 'Runner' }
changed = false
runner.build_configuration_list.build_configurations.each do |config|
  next unless config.name.end_with?("-#{flavor}")

  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = catalog
  puts "#{config.name} -> #{catalog}"
  changed = true
end

if changed
  project.save
  puts 'Saved.'
else
  warn "No '-#{flavor}' build configurations found — run add_ios_flavor.rb #{flavor} first."
  exit 1
end
