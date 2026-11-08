package app.languagelibrary.language_library

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.random.Random

/** Shared helpers. The app writes JSON lists with HomeWidget.saveWidgetData; see lib/device/android_device.dart. */
internal object WidgetData {
    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun list(prefs: SharedPreferences, key: String): JSONArray =
        try { JSONArray(prefs.getString(key, "[]") ?: "[]") } catch (e: Exception) { JSONArray() }

    /** The item for today, else the latest one before today, else null. */
    fun forToday(items: JSONArray): JSONObject? {
        val today = today()
        var best: JSONObject? = null
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            val d = o.optString("d")
            if (d == today) return o
            if (d < today) best = o
        }
        return best
    }

    private val toneColors = intArrayOf(R.color.tone5, R.color.tone1, R.color.tone2, R.color.tone3, R.color.tone4, R.color.tone5)

    /** Characters coloured by their tone digits ("45" for 漂亮), like in the app. */
    fun toned(context: Context, hanzi: String, tones: String, on: Boolean): CharSequence {
        if (!on) return hanzi
        val s = SpannableString(hanzi)
        for (i in hanzi.indices) {
            val t = tones.getOrNull(i)?.digitToIntOrNull() ?: 0
            if (t == 0) continue
            s.setSpan(ForegroundColorSpan(context.getColor(toneColors[t])), i, i + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        return s
    }

    /** As big as the characters fit: short words very large, long phrases smaller. */
    fun hanziSize(v: RemoteViews, hanzi: String, wide: Boolean) {
        val n = hanzi.length
        val sp = if (wide) {
            when { n <= 2 -> 56f; n <= 4 -> 46f; n <= 7 -> 36f; else -> 28f }
        } else {
            when { n <= 2 -> 46f; n <= 3 -> 38f; n <= 5 -> 30f; else -> 24f }
        }
        v.setTextViewTextSize(R.id.hz, TypedValue.COMPLEX_UNIT_SP, sp)
    }

    fun openApp(context: Context, place: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("langlib://$place"))
}

/** 2 × 2: today's word, from a month of days the app works out ahead of time. */
class WordOfDayWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val w = WidgetData.forToday(WidgetData.list(widgetData, "wotd"))
        val tone = widgetData.getBoolean("toneHanzi", true)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_wotd)
            if (w == null) {
                v.setTextViewText(R.id.hz, "语")
                v.setTextViewText(R.id.py, "Open the app once")
                v.setTextViewText(R.id.en, "to get your word of the day")
                v.setOnClickPendingIntent(R.id.hz, WidgetData.openApp(context, "library"))
            } else {
                v.setTextViewText(R.id.hz, WidgetData.toned(context, w.optString("hz"), w.optString("tones"), tone))
                WidgetData.hanziSize(v, w.optString("hz"), wide = false)
                v.setTextViewText(R.id.py, w.optString("py"))
                v.setTextViewText(R.id.en, w.optString("en"))
            }
            val place = if (w == null) "library" else "entry/" + w.optString("id")
            v.setOnClickPendingIntent(android.R.id.background, WidgetData.openApp(context, place))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 2 × 1: cards due today. The app saves a month of daily counts, so it stays right without opening the app. */
class DueWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val today = WidgetData.forToday(WidgetData.list(widgetData, "due"))
        val n = today?.optInt("n", 0) ?: 0
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_due)
            v.setTextViewText(R.id.n, n.toString())
            v.setTextViewText(
                R.id.label,
                when {
                    today == null -> "Open the app to start"
                    n == 0 -> "Nothing due today"
                    n == 1 -> "card due today"
                    else -> "cards due today"
                },
            )
            v.setOnClickPendingIntent(android.R.id.background, WidgetData.openApp(context, "practice"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 4 × 2: a word from the Focus list. Tap it to show the answer, tap Next for another. */
class FocusCardWidget : HomeWidgetProvider() {
    companion object {
        private const val FLIP = "app.languagelibrary.language_library.FOCUS_FLIP"
        private const val NEXT = "app.languagelibrary.language_library.FOCUS_NEXT"
        private const val STATE = "FocusCardWidgetState"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == FLIP || intent.action == NEXT) {
            val state = context.getSharedPreferences(STATE, Context.MODE_PRIVATE)
            val cards = WidgetData.list(HomeWidgetPlugin.getData(context), "focus")
            val edit = state.edit()
            if (intent.action == FLIP) {
                edit.putBoolean("revealed", !state.getBoolean("revealed", false))
            } else {
                val count = cards.length()
                val current = state.getInt("index", 0)
                var next = if (count > 0) Random.nextInt(count) else 0
                if (count > 1 && next == current) next = (next + 1) % count
                edit.putInt("index", next).putBoolean("revealed", false)
            }
            edit.apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FocusCardWidget::class.java))
            onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
            return
        }
        super.onReceive(context, intent)
    }

    private fun self(context: Context, action: String, code: Int): PendingIntent {
        val i = Intent(context, FocusCardWidget::class.java).setAction(action)
        return PendingIntent.getBroadcast(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val cards = WidgetData.list(widgetData, "focus")
        val state = context.getSharedPreferences(STATE, Context.MODE_PRIVATE)
        val revealed = state.getBoolean("revealed", false)
        val tone = widgetData.getBoolean("toneHanzi", true)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_focus)
            if (cards.length() == 0) {
                v.setTextViewText(R.id.hz, "☆")
                v.setTextViewText(R.id.answer, "Star words in the app to see them here")
                v.setViewVisibility(R.id.level, View.GONE)
                v.setViewVisibility(R.id.next, View.GONE)
                v.setOnClickPendingIntent(android.R.id.background, WidgetData.openApp(context, "library"))
            } else {
                val c = cards.getJSONObject(state.getInt("index", 0).coerceIn(0, cards.length() - 1))
                v.setTextViewText(R.id.hz, WidgetData.toned(context, c.optString("hz"), c.optString("tones"), tone))
                WidgetData.hanziSize(v, c.optString("hz"), wide = true)
                v.setTextViewText(
                    R.id.answer,
                    if (revealed) c.optString("py") + "\n" + c.optString("en") else "Tap to show the answer",
                )
                val level = c.optString("level")
                v.setTextViewText(R.id.level, level)
                v.setViewVisibility(R.id.level, if (level.isEmpty()) View.GONE else View.VISIBLE)
                v.setViewVisibility(R.id.next, View.VISIBLE)
                v.setOnClickPendingIntent(R.id.face, self(context, FLIP, 1))
                v.setOnClickPendingIntent(R.id.next, self(context, NEXT, 2))
                v.setOnClickPendingIntent(R.id.level, WidgetData.openApp(context, "entry/" + c.optString("id")))
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
