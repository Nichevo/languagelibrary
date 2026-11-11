import AppIntents
import Foundation
import WidgetKit

// What happens when you tap a button on a widget. These run without opening
// the app, then the widget redraws.

/// Where a quick-question widget is up to: which question, what was picked,
/// and today's score. Widgets asking the same kind of question share it,
/// like on Android.
struct QuizState {
  let feed: String
  private var d: UserDefaults { AppGroup.defaults }
  private func key(_ name: String) -> String { "ios.\(feed).\(name)" }

  var index: Int { d.integer(forKey: key("index")) }
  var picked: Int { d.object(forKey: key("picked")) as? Int ?? -1 }
  private var isToday: Bool { d.string(forKey: key("day")) == WidgetData.dayKey() }
  var right: Int { isToday ? d.integer(forKey: key("right")) : 0 }
  var done: Int { isToday ? d.integer(forKey: key("done")) : 0 }

  func pick(_ option: Int) {
    let questions = WidgetData.list(feed)
    guard picked < 0, !questions.isEmpty else { return }
    let q = questions[min(max(index, 0), questions.count - 1)]
    let ok = option == q.int("right")
    let (r, n) = (right, done)
    d.set(WidgetData.dayKey(), forKey: key("day"))
    d.set(r + (ok ? 1 : 0), forKey: key("right"))
    d.set(n + 1, forKey: key("done"))
    d.set(option, forKey: key("picked"))
    QuizLog.add(id: q.str("id"), method: q.str("method", "widget"), ok: ok,
                shown: d.double(forKey: key("shown")))
  }

  func next() {
    let count = WidgetData.list(feed).count
    d.set(count > 0 ? (index + 1) % count : 0, forKey: key("index"))
    d.set(-1, forKey: key("picked"))
    d.set(Date().timeIntervalSince1970, forKey: key("shown"))
  }
}

/// Answers tapped on widgets, for the app to add to the practice log when it
/// next opens (lib/data/widget_feed.dart widgetAnswers). Same format as Android.
enum QuizLog {
  static func add(id: String, method: String, ok: Bool, shown: Double) {
    guard !id.isEmpty else { return }
    let d = AppGroup.defaults
    var log: [[String: Any]] = WidgetData.list("quizLog")
    let now = Date().timeIntervalSince1970
    let seconds = shown > 0 && now - shown < 600 ? now - shown : 0
    log.append([
      "id": id,
      "ok": ok,
      "at": Int64(now * 1000),
      "ms": Int64(seconds * 1000),
      "method": method,
    ])
    if log.count > 500 { log.removeFirst(log.count - 500) }
    if let data = try? JSONSerialization.data(withJSONObject: log), let s = String(data: data, encoding: .utf8) {
      d.set(s, forKey: "quizLog")
    }
  }
}

struct QuizPick: AppIntent {
  static let title: LocalizedStringResource = "Answer a quick question"
  static let isDiscoverable = false

  @Parameter(title: "Questions") var feed: String
  @Parameter(title: "Answer") var option: Int

  init() {}
  init(feed: String, option: Int) {
    self.feed = feed
    self.option = option
  }

  func perform() async throws -> some IntentResult {
    QuizState(feed: feed).pick(option)
    return .result()
  }
}

struct QuizNext: AppIntent {
  static let title: LocalizedStringResource = "Next quick question"
  static let isDiscoverable = false

  @Parameter(title: "Questions") var feed: String

  init() {}
  init(feed: String) { self.feed = feed }

  func perform() async throws -> some IntentResult {
    QuizState(feed: feed).next()
    return .result()
  }
}

/// The Focus card: which starred word, and whether the answer is showing.
enum FocusState {
  static var index: Int { AppGroup.defaults.integer(forKey: "ios.focus.index") }
  static var revealed: Bool { AppGroup.defaults.bool(forKey: "ios.focus.revealed") }
}

struct FocusFlip: AppIntent {
  static let title: LocalizedStringResource = "Turn the Focus card over"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    AppGroup.defaults.set(!FocusState.revealed, forKey: "ios.focus.revealed")
    return .result()
  }
}

struct FocusNext: AppIntent {
  static let title: LocalizedStringResource = "Next Focus card"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    let count = WidgetData.list("focus").count
    var next = count > 0 ? Int.random(in: 0..<count) : 0
    if count > 1 && next == FocusState.index { next = (next + 1) % count }
    AppGroup.defaults.set(next, forKey: "ios.focus.index")
    AppGroup.defaults.set(false, forKey: "ios.focus.revealed")
    return .result()
  }
}

// MARK: - Choosing the kind of question

enum QuizKindOption: String, AppEnum {
  case mix, meaning, which, pinyin, opposite

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Question"
  static let caseDisplayRepresentations: [QuizKindOption: DisplayRepresentation] = [
    .mix: "Random: all kinds, taking turns",
    .meaning: "What does it mean?",
    .which: "Which one is it?",
    .pinyin: "Pick the pinyin",
    .opposite: "What's the opposite?",
  ]

  /// Where the app saves this kind's questions (QuizKind in lib/data/widget_feed.dart).
  var feed: String {
    switch self {
    case .mix: return "quizMix"
    case .meaning: return "quiz"
    case .which: return "quizWhich"
    case .pinyin: return "quizPinyin"
    case .opposite: return "quizOpposite"
    }
  }
}

struct QuizConfig: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Quick question"
  static let description = IntentDescription("Choose the kind of question this widget asks.")

  @Parameter(title: "Question", default: .mix) var kind: QuizKindOption

  init() {}
  init(kind: QuizKindOption) { self.kind = kind }
}
