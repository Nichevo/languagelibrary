import SwiftUI
import UIKit
import WidgetKit

/// Reads what the app saved for the widgets (lib/device/native_device.dart):
/// JSON lists under "wotd", "due", "focus", "quiz…" and "scales", the same as
/// the Android widgets read (android/.../Widgets.kt).
enum WidgetData {
  static var defaults: UserDefaults { AppGroup.defaults }

  static func list(_ key: String) -> [[String: Any]] {
    guard let raw = defaults.string(forKey: key), let data = raw.data(using: .utf8),
          let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return items
  }

  static var toneHanzi: Bool { defaults.object(forKey: "toneHanzi") as? Bool ?? true }

  static func dayKey(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  /// The item for today, else the latest one before today.
  static func forToday(_ items: [[String: Any]], now: Date = Date()) -> [String: Any]? {
    let today = dayKey(now)
    var best: [String: Any]?
    for o in items {
      let d = o.str("d")
      if d == today { return o }
      if d < today { best = o }
    }
    return best
  }

  /// Midnight tonight, when the day's word, count and scale change.
  static func nextMidnight(after now: Date = Date()) -> Date {
    Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 5),
                              matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
  }

  /// Opens the app at a place, like the Android widgets: "practice", "entry/ID", "scale/3".
  /// The homeWidget query tells the home_widget plugin a widget opened the app.
  static func open(_ place: String) -> URL {
    URL(string: "langlib://\(place)?homeWidget") ?? URL(string: "langlib://library?homeWidget")!
  }
}

extension Dictionary where Key == String, Value == Any {
  func str(_ key: String, _ fallback: String = "") -> String { self[key] as? String ?? fallback }
  func int(_ key: String, _ fallback: Int = 0) -> Int { (self[key] as? NSNumber)?.intValue ?? fallback }
  func bool(_ key: String, _ fallback: Bool) -> Bool { (self[key] as? NSNumber)?.boolValue ?? fallback }
  func strings(_ key: String) -> [String] { self[key] as? [String] ?? [] }
}

// MARK: - Look

/// The app's colours, light and dark.
enum Palette {
  static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
  }

  static let background = dynamic(0xFFFFFF, 0x1B2230)
  static let accent = dynamic(0x0D47A1, 0x90B8F8)
  static let muted = dynamic(0x5A6578, 0xA3ADBF)
  static let option = dynamic(0xEEF2F8, 0x2A3445)
  static let right = dynamic(0x2E7D32, 0x81C784)
  static let rightFill = dynamic(0xDCEFDD, 0x1F3A24)
  static let wrong = dynamic(0xC62828, 0xFF8A80)
  static let wrongFill = dynamic(0xFADBD8, 0x45211F)

  /// Tone colours, the same as in the app (lib/ui/common.dart toneColor).
  static let tones: [Color] = [
    dynamic(0x616161, 0xBDBDBD),
    dynamic(0xD32F2F, 0xFF8A80),
    dynamic(0x2E7D32, 0x81C784),
    dynamic(0x1565C0, 0x64B5F6),
    dynamic(0x7B1FA2, 0xCE93D8),
    dynamic(0x616161, 0xBDBDBD),
  ]
}

extension UIColor {
  convenience init(rgb: UInt32) {
    self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
              blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
  }
}

/// Characters coloured by their tone digits ("45" for 漂亮), like in the app.
func toned(_ hanzi: String, _ tones: String, on: Bool) -> AttributedString {
  guard on else { return AttributedString(hanzi) }
  let digits = Array(tones)
  var out = AttributedString()
  for (i, ch) in hanzi.enumerated() {
    var piece = AttributedString(String(ch))
    let t = i < digits.count ? Int(String(digits[i])) ?? 0 : 0
    if t > 0 && t < Palette.tones.count { piece.foregroundColor = Palette.tones[t] }
    out += piece
  }
  return out
}

/// As big as the characters fit: short words very large, long phrases smaller.
func hanziSize(_ hanzi: String, roomy: Bool) -> CGFloat {
  let n = hanzi.count
  if roomy { return n <= 2 ? 60 : n <= 4 ? 48 : n <= 7 ? 36 : 28 }
  return n <= 2 ? 44 : n <= 3 ? 38 : n <= 5 ? 30 : 24
}

struct Caption: View {
  let text: String
  var body: some View {
    Text(text).font(.system(size: 11, weight: .bold)).kerning(0.8).foregroundStyle(Palette.accent).lineLimit(1)
  }
}

extension View {
  func widgetLook() -> some View {
    containerBackground(for: .widget) { Palette.background }
  }
}
