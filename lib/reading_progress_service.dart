import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran/quran.dart' as quran;

class ReadingStatus {
  final int goalDays;
  final DateTime startDate;
  final int? lastSurah;
  final int? lastVerse;
  final int lastGlobalIndex;
  final int todayRead;
  final int dailyTarget;
  final double percent;

  const ReadingStatus({
    required this.goalDays,
    required this.startDate,
    required this.lastSurah,
    required this.lastVerse,
    required this.lastGlobalIndex,
    required this.todayRead,
    required this.dailyTarget,
    required this.percent,
  });
}

class ReadingProgressService {
  static const _kGoalDays = 'khatma_goal_days';
  static const _kStartDate = 'khatma_start_date';
  static const _kLastSurah = 'khatma_last_surah';
  static const _kLastVerse = 'khatma_last_verse';
  static const _kLastGlobal = 'khatma_last_global_index';

  static const _kTodayKey = 'khatma_today_key';
  static const _kTodayRead = 'khatma_today_read';

  static const _kReminderEnabled = 'khatma_reminder_enabled';
  static const _kReminderHHMM = 'khatma_reminder_time';
  static const _kReminderLastShown = 'khatma_reminder_last_shown_date';

  static const int totalAyat = 6236;

  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static Future<void> ensureInitialized() async {
    final p = await SharedPreferences.getInstance();
    p.setInt(_kGoalDays, p.getInt(_kGoalDays) ?? 30);
    p.setString(
      _kStartDate,
      p.getString(_kStartDate) ?? _dateKey(DateTime.now()),
    );
    p.setInt(_kLastGlobal, p.getInt(_kLastGlobal) ?? 1);

    final today = _dateKey(DateTime.now());
    p.setString(_kTodayKey, p.getString(_kTodayKey) ?? today);
    p.setInt(_kTodayRead, p.getInt(_kTodayRead) ?? 0);

    p.setBool(_kReminderEnabled, p.getBool(_kReminderEnabled) ?? true);
    p.setString(_kReminderHHMM, p.getString(_kReminderHHMM) ?? '21:00');
    p.setString(_kReminderLastShown, p.getString(_kReminderLastShown) ?? '');
  }

  static int _globalAyahIndex(int surah, int verse) {
    int sum = 0;
    for (int s = 1; s < surah; s++) {
      sum += quran.getVerseCount(s);
    }
    return sum + verse;
  }

  static int _dailyTarget(int goalDays) {
    final d = goalDays <= 0 ? 30 : goalDays;
    final target = (totalAyat / d).ceil();
    return target < 1 ? 1 : target;
  }

  static Future<void> saveProgress({
    required int surah,
    required int verse,
  }) async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();

    final now = DateTime.now();
    final today = _dateKey(now);

    final newGlobal = _globalAyahIndex(surah, verse);
    final prevGlobal = p.getInt(_kLastGlobal) ?? 1;

    final savedToday = p.getString(_kTodayKey);
    int todayRead = p.getInt(_kTodayRead) ?? 0;
    if (savedToday != today) {
      todayRead = 0;
      await p.setString(_kTodayKey, today);
    }

    final diff = (newGlobal > prevGlobal) ? (newGlobal - prevGlobal) : 0;
    todayRead += diff;

    await p.setInt(_kTodayRead, todayRead);
    await p.setInt(_kLastSurah, surah);
    await p.setInt(_kLastVerse, verse);
    await p.setInt(_kLastGlobal, newGlobal);
  }

  static Future<ReadingStatus> getStatus() async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();

    final goalDays = p.getInt(_kGoalDays) ?? 30;
    final startStr = p.getString(_kStartDate) ?? _dateKey(DateTime.now());
    final start = DateTime.tryParse(startStr) ?? DateTime.now();

    final lastSurah = p.getInt(_kLastSurah);
    final lastVerse = p.getInt(_kLastVerse);
    final lastGlobal = p.getInt(_kLastGlobal) ?? 1;

    final todayKey = _dateKey(DateTime.now());
    final savedToday = p.getString(_kTodayKey);
    final todayRead = (savedToday == todayKey)
        ? (p.getInt(_kTodayRead) ?? 0)
        : 0;

    final dailyTarget = _dailyTarget(goalDays);
    final percent = (lastGlobal / totalAyat).clamp(0.0, 1.0);

    return ReadingStatus(
      goalDays: goalDays,
      startDate: start,
      lastSurah: lastSurah,
      lastVerse: lastVerse,
      lastGlobalIndex: lastGlobal,
      todayRead: todayRead,
      dailyTarget: dailyTarget,
      percent: percent,
    );
  }

  static Future<void> setGoalDays(int days) async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    await p.setInt(_kGoalDays, days.clamp(1, 365));
  }

  static Future<void> resetKhatma() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await p.setString(_kStartDate, _dateKey(now));
    await p.remove(_kLastSurah);
    await p.remove(_kLastVerse);
    await p.setInt(_kLastGlobal, 1);
    await p.setString(_kTodayKey, _dateKey(now));
    await p.setInt(_kTodayRead, 0);
  }

  static Future<bool> getReminderEnabled() async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    return p.getBool(_kReminderEnabled) ?? true;
  }

  static Future<String> getReminderTimeHHMM() async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    return p.getString(_kReminderHHMM) ?? '21:00';
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    await p.setBool(_kReminderEnabled, enabled);
  }

  static Future<void> setReminderTimeHHMM(String hhmm) async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    await p.setString(_kReminderHHMM, hhmm);
  }

  static Future<String> getReminderLastShownDate() async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    return p.getString(_kReminderLastShown) ?? '';
  }

  static Future<void> setReminderLastShownDate(String dayKey) async {
    final p = await SharedPreferences.getInstance();
    await ensureInitialized();
    await p.setString(_kReminderLastShown, dayKey);
  }
}
