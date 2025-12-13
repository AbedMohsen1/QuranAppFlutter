import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService {
  static const _favoritesKey = 'favorite_ayahs';

  Future<void> addFavorite(String surah, int ayah, String note) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    final entry = jsonEncode({'surah': surah, 'ayah': ayah, 'note': note});
    favorites.add(entry);
    await prefs.setStringList(_favoritesKey, favorites);
  }

  Future<List> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    return favorites.map((e) => jsonDecode(e)).toList();
  }

  Future<void> removeFavorite(String surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];
    favorites.removeWhere((e) {
      final map = jsonDecode(e);
      return map['surah'] == surah && map['ayah'] == ayah;
    });
    await prefs.setStringList(_favoritesKey, favorites);
  }
}
