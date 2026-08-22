#!/usr/bin/env ruby
# Adds one white-label tenant flavor to ios/Runner.xcodeproj: duplicates the
# Debug/Release/Profile build configurations (project-level + every target)
# under a "-<flavor>" suffix, points the Runner target's copies at the
# tenant's bundle id/display name, and (once, idempotently) adds a Run
# Script build phase that swaps in the right GoogleService-Info.plist based
# on which configuration is building.
#
# Usage: ruby scripts/add_ios_flavor.rb <flavor> <bundle_id> <display_name>
#   ruby scripts/add_ios_flavor.rb myneedmart com.myneedmart.iosapp "My Need Mart"
#
# After running: also add matching entries to the `project 'Runner', {...}`
# map in ios/Podfile, drop ios/Flavors/<flavor>/GoogleService-Info.plist,
# and run `pod install`.

require 'xcodeproj'

flavor, bundle_id, display_name = ARGV
if flavor.nil? || bundle_id.nil? || display_name.nil?
  warn 'Usage: add_ios_flavor.rb <flavor> <bundle_id> <display_name>'
  exit 1
end

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
base_names = %w[Debug Release Profile]

def add_configs(config_list, base_names, flavor, overrides_for_base = {})
  base_names.each do |base|
    src = config_list.build_configurations.find { |c| c.name == base }
    next unless src

    new_name = "#{base}-#{flavor}"
    next if config_list.build_configurations.any? { |c| c.name == new_name }

    new_config = config_list.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    new_config.name = new_name
    new_config.build_settings = src.build_settings.dup
    new_config.base_configuration_reference = src.base_configuration_reference
    overrides_for_base.each { |k, v| new_config.build_settings[k] = v }
    config_list.build_configurations << new_config
    puts "  + #{config_list.build_configurations.length > 0 ? '' : ''}#{new_name}"
  end
end

# 1. Project-level configuration list (names must exist here for Xcode/
#    xcodebuild to accept them as valid configurations at all).
puts "Project-level configs:"
add_configs(project.root_object.build_configuration_list, base_names, flavor)

# 2. Every target — Runner gets the real bundle id/display name override;
#    RunnerTests (and any others) just get same-valued duplicates so the
#    configuration name is consistent across the whole project.
project.targets.each do |target|
  puts "#{target.name} configs:"
  overrides = target.name == 'Runner' ? {
    'PRODUCT_BUNDLE_IDENTIFIER' => bundle_id,
    'APP_DISPLAY_NAME' => display_name,
  } : {}
  add_configs(target.build_configuration_list, base_names, flavor, overrides)
end

# 3. Give the *existing* (non-flavor) Runner configs an APP_DISPLAY_NAME too,
#    the first time this script runs, so Info.plist can use $(APP_DISPLAY_NAME)
#    uniformly without changing current (pagariya) behaviour.
runner = project.targets.find { |t| t.name == 'Runner' }
runner.build_configuration_list.build_configurations.each do |config|
  next if config.name.include?('-')
  config.build_settings['APP_DISPLAY_NAME'] ||= "Patel's R Mart"
end

# 4. Firebase config selection script phase — added once, works for every
#    flavor by reading $CONFIGURATION at build time. Idempotent.
phase_name = 'Select Firebase config for flavor'
unless runner.shell_script_build_phases.any? { |p| p.name == phase_name }
  phase = runner.new_shell_script_build_phase(phase_name)
  phase.shell_script = <<~SCRIPT
    CONFIG_NAME="${CONFIGURATION}"
    if [[ "$CONFIG_NAME" == *-* ]]; then
      FLAVOR="${CONFIG_NAME##*-}"
      SRC="${PROJECT_DIR}/Flavors/${FLAVOR}/GoogleService-Info.plist"
      DEST="${PROJECT_DIR}/Runner/GoogleService-Info.plist"
      if [ -f "$SRC" ]; then
        cp "$SRC" "$DEST"
        echo "Flavor '$FLAVOR': copied GoogleService-Info.plist"
      else
        echo "warning: no GoogleService-Info.plist for flavor '$FLAVOR' at $SRC — leaving existing file in place"
      fi
    fi
  SCRIPT
  # Run before "Copy Bundle Resources" so the swapped-in file is the one
  # that actually gets bundled into the .app.
  runner.build_phases.delete(phase)
  runner.build_phases.unshift(phase)
  puts "Added '#{phase_name}' run script phase."
end

project.save
puts "Saved #{project_path}"
