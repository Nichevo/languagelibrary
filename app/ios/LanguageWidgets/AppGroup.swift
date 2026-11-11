import Foundation

/// The space the app and its widgets share, where the app leaves each widget's
/// words and questions (lib/device/native_device.dart) and the widgets leave the
/// answers tapped on them.
///
/// AltStore gives the group a new name when it installs the app with your Apple
/// ID, and writes the new name into Info.plist under ALTAppGroups, so both the
/// app and the widgets look there first. This file is part of both targets.
enum AppGroup {
  static let standard = "group.app.languagelibrary.languageLibrary"

  static let id: String = {
    for bundle in bundles() {
      if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
         let group = groups.first(where: { $0.hasPrefix(standard) }) ?? groups.first {
        return group
      }
    }
    return standard
  }()

  static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }

  /// This bundle, and from a widget also the app around it
  /// (Runner.app/PlugIns/LanguageWidgets.appex).
  private static func bundles() -> [Bundle] {
    var found = [Bundle.main]
    let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    if app.pathExtension == "app", let b = Bundle(url: app) { found.append(b) }
    return found
  }
}
