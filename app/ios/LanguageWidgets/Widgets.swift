import AppIntents
import SwiftUI
import WidgetKit

/// The iPad (and iPhone) home-screen widgets. Each matches one on Android
/// (android/.../Widgets.kt) and reads the same data the app saves ahead of time.
@main
struct LanguageLibraryWidgets: WidgetBundle {
  var body: some Widget {
    QuizWidget()
    WordOfDayWidget()
    DueWidget()
    FocusCardWidget()
    ScaleWidget()
  }
}

/// One entry that lasts until midnight, for widgets that change once a day.
struct DayEntry: TimelineEntry {
  let date: Date
}

struct DayProvider: TimelineProvider {
  func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date()) }
  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    completion(DayEntry(date: Date()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    let now = Date()
    completion(Timeline(entries: [DayEntry(date: now)], policy: .after(WidgetData.nextMidnight(after: now))))
  }
}

// MARK: - Quick question

struct QuizEntry: TimelineEntry {
  let date: Date
  let kind: QuizKindOption
}

struct QuizProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> QuizEntry { QuizEntry(date: Date(), kind: .meaning) }
  func snapshot(for configuration: QuizConfig, in context: Context) async -> QuizEntry {
    QuizEntry(date: Date(), kind: configuration.kind)
  }
  func timeline(for configuration: QuizConfig, in context: Context) async -> Timeline<QuizEntry> {
    let now = Date()
    // Redrawn after every tap; midnight resets the day's score.
    return Timeline(entries: [QuizEntry(date: now, kind: configuration.kind)],
                    policy: .after(WidgetData.nextMidnight(after: now)))
  }
}

struct QuizWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "QuizWidget", intent: QuizConfig.self, provider: QuizProvider()) { entry in
      QuizView(entry: entry)
    }
    .configurationDisplayName("Quick question")
    .description("Tap an answer right on the home screen. Hold the widget and choose Edit Widget to pick the kind of question.")
    .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
  }
}

struct QuizView: View {
  let entry: QuizEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let feed = entry.kind.feed
    let questions = WidgetData.list(feed)
    Group {
      if questions.isEmpty {
        VStack(spacing: 8) {
          Text("?").font(.system(size: 48, weight: .semibold))
          Text("Open the app once to get questions").font(.callout).foregroundStyle(Palette.muted)
        }
        .widgetURL(WidgetData.open("library"))
      } else {
        let state = QuizState(feed: feed)
        let q = questions[min(max(state.index, 0), questions.count - 1)]
        if family == .systemMedium {
          HStack(spacing: 12) {
            face(q, state: state, compact: true).frame(maxWidth: .infinity)
            options(q, state: state, feed: feed, compact: true).frame(maxWidth: .infinity)
          }
        } else {
          VStack(spacing: 10) {
            face(q, state: state, compact: false)
            Spacer(minLength: 0)
            options(q, state: state, feed: feed, compact: false)
          }
        }
      }
    }
    .widgetLook()
  }

  /// The title, the word (or meaning), and after a pick the answer.
  @ViewBuilder
  private func face(_ q: [String: Any], state: QuizState, compact: Bool) -> some View {
    let big = q.str("big", q.str("hz"))
    let bigHanzi = q.bool("bigHanzi", true)
    let picked = state.picked
    let answer = q.int("right")
    VStack(spacing: compact ? 2 : 6) {
      HStack {
        Caption(text: q.str("title", "WHAT DOES IT MEAN?"))
        Spacer(minLength: 4)
        if state.done > 0 {
          Text("\(state.right) of \(state.done) today").font(.caption2).foregroundStyle(Palette.muted)
        }
      }
      Link(destination: WidgetData.open("entry/\(q.str("id"))")) {
        if bigHanzi {
          Text(toned(big, q.str("tones"), on: WidgetData.toneHanzi))
            .font(.system(size: compact ? hanziSize(big, roomy: false) : hanziSize(big, roomy: true), weight: .medium))
            .lineLimit(1).minimumScaleFactor(0.5)
        } else {
          Text(big).font(.system(size: big.count <= 14 ? (compact ? 22 : 30) : (compact ? 16 : 22), weight: .semibold))
            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
        }
      }
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity, maxHeight: compact ? CGFloat.infinity : nil)
      Text(picked >= 0 ? q.str("after", q.str("py")) : " ")
        .font(compact ? .caption : .body).foregroundStyle(Palette.muted).lineLimit(1)
      Text(status(q, picked: picked, answer: answer))
        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
        .foregroundStyle(picked < 0 ? Palette.muted : picked == answer ? Palette.right : Palette.wrong)
        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
    }
  }

  private func status(_ q: [String: Any], picked: Int, answer: Int) -> String {
    if picked < 0 { return "Tap an answer" }
    if picked == answer { return q.str("rightMsg", "Right!") }
    let opts = q.strings("opts")
    return q.str("wrongMsg", "It means: \(answer < opts.count ? opts[answer] : "")")
  }

  /// Four answers to tap, then Next.
  @ViewBuilder
  private func options(_ q: [String: Any], state: QuizState, feed: String, compact: Bool) -> some View {
    let opts = q.strings("opts")
    let optsHanzi = q.bool("optsHanzi", false)
    let picked = state.picked
    let answer = q.int("right")
    VStack(spacing: compact ? 6 : 8) {
      Grid(horizontalSpacing: compact ? 6 : 8, verticalSpacing: compact ? 6 : 8) {
        ForEach(0..<2, id: \.self) { row in
          GridRow {
            ForEach(0..<2, id: \.self) { col in
              let n = row * 2 + col
              Button(intent: QuizPick(feed: feed, option: n)) {
                Text(n < opts.count ? opts[n] : "")
                  .font(optsHanzi ? .system(size: compact ? 20 : 26) : .system(size: compact ? 13 : 16))
                  .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
                  .frame(maxWidth: .infinity, minHeight: compact ? 34 : 50)
                  .padding(.horizontal, 4)
                  .background(fill(n, picked: picked, answer: answer), in: RoundedRectangle(cornerRadius: 12))
                  .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                    picked >= 0 && n == answer ? Palette.right : .clear, lineWidth: 2))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      Button(intent: QuizNext(feed: feed)) {
        Text(picked >= 0 ? "Next" : "Skip")
          .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
          .foregroundStyle(Palette.accent)
          .frame(maxWidth: .infinity, minHeight: compact ? 22 : 30)
      }
      .buttonStyle(.plain)
    }
  }

  private func fill(_ n: Int, picked: Int, answer: Int) -> Color {
    if picked < 0 { return Palette.option }
    if n == answer { return Palette.rightFill }
    if n == picked { return Palette.wrongFill }
    return Palette.option
  }
}

// MARK: - Word of the day

struct WordOfDayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WordOfDayWidget", provider: DayProvider()) { _ in WordOfDayView() }
      .configurationDisplayName("Word of the day")
      .description("A new word each day. Tap it to open the word.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WordOfDayView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let w = WidgetData.forToday(WidgetData.list("wotd"))
    let hz = w?.str("hz") ?? "语"
    VStack(alignment: family == .systemSmall ? .leading : .center, spacing: 4) {
      Caption(text: "WORD OF THE DAY")
      Spacer(minLength: 0)
      Text(toned(hz, w?.str("tones") ?? "", on: w != nil && WidgetData.toneHanzi))
        .font(.system(size: hanziSize(hz, roomy: family != .systemSmall), weight: .medium))
        .lineLimit(1).minimumScaleFactor(0.5)
      Text(w?.str("py") ?? "Open the app once").font(.headline).lineLimit(1)
      Text(w?.str("en") ?? "to get your word of the day").font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: family == .systemSmall ? .leading : .center)
    .widgetURL(WidgetData.open(w == nil ? "library" : "entry/\(w!.str("id"))"))
    .widgetLook()
  }
}

// MARK: - Cards due

struct DueWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DueWidget", provider: DayProvider()) { _ in DueView() }
      .configurationDisplayName("Cards due")
      .description("How many flashcards are due today. Tap to practise.")
      .supportedFamilies([.systemSmall])
  }
}

struct DueView: View {
  var body: some View {
    let today = WidgetData.forToday(WidgetData.list("due"))
    let n = today?.int("n") ?? 0
    VStack(alignment: .leading, spacing: 4) {
      Caption(text: "CARDS DUE")
      Spacer(minLength: 0)
      Text("\(n)").font(.system(size: 52, weight: .heavy, design: .rounded)).foregroundStyle(Palette.accent)
      Text(today == nil ? "Open the app to start" : n == 0 ? "Nothing due today" : n == 1 ? "card due today" : "cards due today")
        .font(.caption).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(WidgetData.open("practice"))
    .widgetLook()
  }
}

// MARK: - Focus card

struct FocusCardWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FocusCardWidget", provider: DayProvider()) { _ in FocusCardView() }
      .configurationDisplayName("Focus card")
      .description("A word from your Focus list. Tap to turn it over, Next for another.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FocusCardView: View {
  var body: some View {
    let cards = WidgetData.list("focus")
    Group {
      if cards.isEmpty {
        VStack(spacing: 6) {
          Text("☆").font(.system(size: 40))
          Text("Star words in the app to see them here").font(.caption).foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
        }
        .widgetURL(WidgetData.open("library"))
      } else {
        let c = cards[min(max(FocusState.index, 0), cards.count - 1)]
        let hz = c.str("hz")
        VStack(spacing: 4) {
          HStack {
            Caption(text: "FOCUS")
            Spacer(minLength: 4)
            if !c.str("level").isEmpty {
              Link(destination: WidgetData.open("entry/\(c.str("id"))")) {
                Text(c.str("level")).font(.caption2.weight(.semibold)).foregroundStyle(Palette.accent)
              }
            }
          }
          Button(intent: FocusFlip()) {
            VStack(spacing: 2) {
              Text(toned(hz, c.str("tones"), on: WidgetData.toneHanzi))
                .font(.system(size: hanziSize(hz, roomy: false), weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.5)
              if FocusState.revealed {
                Text(c.str("py")).font(.subheadline).lineLimit(1)
                Text(c.str("en")).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                  .multilineTextAlignment(.center)
              } else {
                Text("Tap to show the answer").font(.caption).foregroundStyle(Palette.muted)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Button(intent: FocusNext()) {
            Text("Next").font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
              .frame(maxWidth: .infinity, minHeight: 20)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .widgetLook()
  }
}

// MARK: - Scale

struct ScaleWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ScaleWidget", provider: DayProvider()) { _ in ScaleView() }
      .configurationDisplayName("Scale of the day")
      .description("Words in order, like cold to hot. A different scale each day.")
      .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct ScaleView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let s = WidgetData.forToday(WidgetData.list("scales"))
    let words = Array(((s?["words"] as? [[String: Any]]) ?? []).prefix(5))
    let large = family == .systemLarge
    VStack(alignment: .leading, spacing: 6) {
      Caption(text: (s?.str("name") ?? "SCALE OF THE DAY").uppercased())
      Text(s == nil ? "Open the app once to get scales" : "\(s!.str("ends")) · tap to open")
        .font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
      Spacer(minLength: 0)
      HStack(alignment: .top, spacing: 6) {
        ForEach(0..<words.count, id: \.self) { i in
          let w = words[i]
          let hz = w.str("hz")
          VStack(spacing: 2) {
            Text(hz).font(.system(size: scaleSize(hz, count: words.count, large: large), weight: .medium))
              .lineLimit(1).minimumScaleFactor(0.5)
            Text(w.str("py")).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            Text(w.str("en")).font(.caption2).foregroundStyle(Palette.muted).lineLimit(2)
              .multilineTextAlignment(.center).minimumScaleFactor(0.7)
          }
          .frame(maxWidth: .infinity)
        }
      }
      Spacer(minLength: 0)
    }
    .widgetURL(WidgetData.open(s == nil ? "library" : "scale/\(s!.int("i"))"))
    .widgetLook()
  }

  private func scaleSize(_ hz: String, count: Int, large: Bool) -> CGFloat {
    let base: CGFloat = hz.count <= 1 ? 40 : hz.count == 2 ? 30 : 22
    return (count >= 5 ? base * 0.8 : base) * (large ? 1.25 : 1)
  }
}
