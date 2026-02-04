require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

if target
  puts "Updating build settings for target: #{target.name}"
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
    puts "  - Linked Runner.entitlements in #{config.name} configuration"
  end
  project.save
  puts "Successfully saved project changes."
else
  puts "Error: Runner target not found!"
  exit 1
end
