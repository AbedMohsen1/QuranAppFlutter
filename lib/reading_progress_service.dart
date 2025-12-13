import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgressService {
  static const _lastSurahKey = 'last_surah';
  static const _lastPageKey = 'last_page';
  static const _goalDaysKey = 'goal_days';

  Future<void> saveProgress({required String surah, required int page}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSurahKey, surah);
    await prefs.setInt(_lastPageKey, page);
  }

  Future<Map<String, dynamic>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'surah': prefs.getString(_lastSurahKey) ?? '',
      'page': prefs.getInt(_lastPageKey) ?? 1,
    };
  }

  Future<void> setGoalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalDaysKey, days);
  }

  Future<int> getGoalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalDaysKey) ?? 30;
  }
}
