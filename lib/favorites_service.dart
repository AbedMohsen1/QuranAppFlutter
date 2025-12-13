import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavItem {
  final String id; // "surah:verse"
  final int surah;
  final int verse;
  final String surahName;
  final String verseText;
  final String? note;
  final int createdAt; // ms epoch

  const FavItem({
    required this.id,
    required this.surah,
    required this.verse,
    required this.surahName,
    required this.verseText,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'surah': surah,
    'verse': verse,
    'surahName': surahName,
    'verseText': verseText,
    'note': note,
    'createdAt': createdAt,
  };

  static FavItem fromJson(Map<String, dynamic> j) => FavItem(
    id: j['id'] as String,
    surah: (j['surah'] as num).toInt(),
    verse: (j['verse'] as num).toInt(),
    surahName: (j['surahName'] ?? '') as String,
    verseText: (j['verseText'] ?? '') as String,
    note: j['note'] as String?,
    createdAt: (j['createdAt'] as num).toInt(),
  );
}

class FavoritesService {
  static const _kFav = 'fav_items_v1';

  static String _makeId(int surah, int verse) => '$surah:$verse';

  static Future<List<FavItem>> getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kFav);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final items = list.map(FavItem.fromJson).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<FavItem?> getItem(int surah, int verse) async {
    final id = _makeId(surah, verse);
    final items = await getAll();
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isFavorite(int surah, int verse) async {
    return (await getItem(surah, verse)) != null;
  }

  static Future<void> addOrUpdate({
    required int surah,
    required int verse,
    required String surahName,
    required String verseText,
    String? note,
  }) async {
    final p = await SharedPreferences.getInstance();
    final id = _makeId(surah, verse);

    final items = await getAll();
    final idx = items.indexWhere((e) => e.id == id);

    final newItem = FavItem(
      id: id,
      surah: surah,
      verse: verse,
      surahName: surahName,
      verseText: verseText,
      note: (note != null && note.trim().isEmpty) ? null : note?.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (idx >= 0) {
      // حافظ على createdAt القديم لو بدك (هنا بنخليه جديد عشان يطلع فوق)
      items[idx] = newItem;
    } else {
      items.insert(0, newItem);
    }

    await p.setString(_kFav, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> remove(int surah, int verse) async {
    final p = await SharedPreferences.getInstance();
    final id = _makeId(surah, verse);
    final items = await getAll();
    items.removeWhere((e) => e.id == id);
    await p.setString(_kFav, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> updateNote(int surah, int verse, String? note) async {
    final p = await SharedPreferences.getInstance();
    final id = _makeId(surah, verse);
    final items = await getAll();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;

    final old = items[idx];
    final updated = FavItem(
      id: old.id,
      surah: old.surah,
      verse: old.verse,
      surahName: old.surahName,
      verseText: old.verseText,
      note: (note != null && note.trim().isEmpty) ? null : note?.trim(),
      createdAt: old.createdAt,
    );

    items[idx] = updated;
    await p.setString(_kFav, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
