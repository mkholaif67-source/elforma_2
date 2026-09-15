package com.elforma.elforma

import android.content.Context
import java.time.LocalDate
import kotlin.math.roundToInt

/** Device-local step history. It starts on the day tracking is enabled and never
 * invents rows for dates before that day. No network or app server is involved. */
object StepTrackingStore {
    private const val PREFS = "elforma_steps"
    private const val START = "tracking_start_date"
    private const val ENABLED = "tracking_enabled"
    private const val COUNTER_TOTAL = "counter_last_total"
    private const val COUNTER_DATE = "counter_last_date"
    private const val COUNT_PREFIX = "day_count:"

    @Synchronized
    fun enable(context: Context, today: LocalDate = LocalDate.now()): LocalDate {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(START, null)
        val start = runCatching { existing?.let { LocalDate.parse(it) } }.getOrNull() ?: today
        val edit = prefs.edit().putBoolean(ENABLED, true).putString(START, start.toString())
        if (!prefs.contains(COUNT_PREFIX + start)) edit.putInt(COUNT_PREFIX + start, 0)
        edit.apply()
        return start
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ENABLED, false)

    fun startDate(context: Context, today: LocalDate = LocalDate.now()): LocalDate = enable(context, today)

    @Synchronized
    fun recordCounter(context: Context, total: Float, today: LocalDate = LocalDate.now()) {
        if (!total.isFinite() || total < 0f) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = COUNT_PREFIX + today
        val hadDailyCount = prefs.contains(key)
        enable(context, today)

        // Migrate once from the earlier activity-only baseline without counting
        // the same delta twice. The next sensor event continues from this total.
        if (!hadDailyCount) {
            val oldDate = prefs.getString("baseline_date", null)
            val oldBaseline = prefs.getFloat("baseline_total", total)
            val migrated = if (oldDate == today.toString() && total >= oldBaseline)
                (total - oldBaseline).roundToInt().coerceAtLeast(0) else 0
            prefs.edit()
                .putInt(key, migrated)
                .putFloat(COUNTER_TOTAL, total)
                .putString(COUNTER_DATE, today.toString())
                .putFloat("last_total", total)
                .apply()
            return
        }

        val fallbackLast = if (prefs.contains("last_total")) prefs.getFloat("last_total", total) else total
        val previous = if (prefs.contains(COUNTER_TOTAL)) prefs.getFloat(COUNTER_TOTAL, fallbackLast) else fallbackLast
        val previousDate = prefs.getString(COUNTER_DATE, today.toString())
        val delta = if (total >= previous) (total - previous).roundToInt() else 0 // sensor resets after reboot
        val safeDelta = delta.coerceIn(0, 100000)
        val current = prefs.getInt(key, 0)
        prefs.edit()
            .putInt(key, current + safeDelta)
            .putFloat(COUNTER_TOTAL, total)
            .putString(COUNTER_DATE, today.toString())
            .putFloat("last_total", total)
            .putString("last_event_date", previousDate)
            .apply()
    }

    @Synchronized
    fun recordDetector(context: Context, steps: Int = 1, today: LocalDate = LocalDate.now()) {
        if (steps <= 0) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        enable(context, today)
        val key = COUNT_PREFIX + today
        prefs.edit().putInt(key, prefs.getInt(key, 0) + steps.coerceAtMost(100)).apply()
    }

    fun todayCount(context: Context, today: LocalDate = LocalDate.now()): Int {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        enable(context, today)
        return prefs.getInt(COUNT_PREFIX + today, 0)
    }

    fun recentDays(context: Context, today: LocalDate = LocalDate.now()): List<MutableMap<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val start = enable(context, today)
        val firstAllowed = today.minusDays(6)
        var day = if (start.isAfter(firstAllowed)) start else firstAllowed
        val result = mutableListOf<MutableMap<String, Any?>>()
        while (!day.isAfter(today)) {
            val key = COUNT_PREFIX + day
            result.add(mutableMapOf("day" to day.toString(), "count" to if (prefs.contains(key)) prefs.getInt(key, 0) else null))
            day = day.plusDays(1)
        }
        return result
    }
}
