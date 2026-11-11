# Adds the home-screen widget extension (app/ios/LanguageWidgets) to the Xcode
# project, since there is no Mac to do it in Xcode. Run once from the repo root:
#   gem install xcodeproj && ruby tools/ios/add_widget_target.rb
# Running it again does nothing if the target is already there.
require 'xcodeproj'

project_path = File.expand_path('../../app/ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
name = 'LanguageWidgets'
if project.targets.any? { |t| t.name == name }
  puts "#{name} is already in the project"
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
widget = project.new_target(:app_extension, name, :ios, '17.0', nil, :swift)
# Swift links SwiftUI, WidgetKit and Foundation by itself, so drop the
# Foundation.framework the gem adds, which names one particular Xcode's SDK.
widget.frameworks_build_phase.files.to_a.each do |f|
  ref = f.file_ref
  widget.frameworks_build_phase.remove_build_file(f)
  ref&.remove_from_project
end

# Source files: everything in LanguageWidgets. AppGroup.swift is in the app too.
group = project.main_group.new_group(name, name)
sources = %w[AppGroup.swift WidgetData.swift Intents.swift Widgets.swift]
refs = sources.map { |f| group.new_reference(f) }
group.new_reference('Info.plist')
group.new_reference("#{name}.entitlements")
widget.add_file_references(refs)
runner.add_file_references([refs.first])

# The app's own entitlements file, for the shared app group.
runner_group = project.main_group['Runner']
runner_group.new_reference('Runner.entitlements')

# Flutter's version numbers for the widget's Info.plist, without CocoaPods' settings.
flutter_group = project.main_group['Flutter']
# The Flutter group has no folder of its own, so the path includes Flutter/.
widget_xcconfig = flutter_group.new_reference('Flutter/Widget.xcconfig')
widget_xcconfig.name = 'Widget.xcconfig'

# Profile configuration, like the rest of a Flutter project.
unless widget.build_configurations.any? { |c| c.name == 'Profile' }
  release = widget.build_configurations.find { |c| c.name == 'Release' }
  profile = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  profile.name = 'Profile'
  profile.build_settings = release.build_settings.dup
  widget.build_configuration_list.build_configurations << profile
end

widget.build_configurations.each do |config|
  config.base_configuration_reference = widget_xcconfig
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.languagelibrary.languageLibrary.LanguageWidgets'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{name}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SWIFT_VERSION'] = '5.0'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['ENABLE_BITCODE'] = 'NO'
  s.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
  s.delete('ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME')
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Build the widget with the app and put it inside the app.
runner.add_dependency(widget)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.dst_subfolder_spec = '13' # PlugIns
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Flutter's "Thin Binary" script must run after the widget is copied in, or
# Xcode reports a dependency cycle. Put the copy right after Resources.
runner.build_phases.delete(embed)
resources_at = runner.build_phases.index { |p| p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
runner.build_phases.insert(resources_at + 1, embed)

frameworks = project.main_group.children.find { |g| g.display_name == 'Frameworks' && g.children.all? { |c| c.respond_to?(:children) && c.children.empty? } }
frameworks&.remove_from_project
project.save
puts "Added #{name} to #{project_path}"
