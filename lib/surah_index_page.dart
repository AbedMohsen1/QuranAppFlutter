import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/surah_detail_page.dart';

class SurahIndexPage extends StatefulWidget {
  const SurahIndexPage({super.key});

  @override
  State<SurahIndexPage> createState() => _SurahIndexPageState();
}

class _SurahIndexPageState extends State<SurahIndexPage> {
  int? selectedSurah;

  @override
  void initState() {
    super.initState();
    loadSelectedSurah();
  }

  Future<void> loadSelectedSurah() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSurah = prefs.getInt('selected_surah');
    });
  }

  Future<void> saveSelectedSurah(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_surah', surahNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('فهرس السور', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        itemCount: quran.totalSurahCount,
        itemBuilder: (context, index) {
          int surahNumber = index + 1;
          String surahName = quran.getSurahNameArabic(surahNumber);
          String revelationPlace = quran.getPlaceOfRevelation(surahNumber);
          int verseCount = quran.getVerseCount(surahNumber);
          int juzNumber = quran.getJuzNumber(surahNumber, 1); // ⬅️ الجزء
          bool isSelected = selectedSurah == surahNumber;

          return Container(
            color: isSelected ? Colors.red.withOpacity(0.1) : null,
            child: ListTile(
              leading: Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  'جزء $juzNumber',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.red : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              title: Text(
                '$surahNumber. $surahName',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: isSelected ? Colors.red : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'مكان النزول: $revelationPlace - عدد الآيات: $verseCount',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: isSelected ? Colors.red : Colors.grey),
              ),
              onTap: () async {
                await saveSelectedSurah(surahNumber);
                setState(() {
                  selectedSurah = surahNumber;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurahDetailPage(surahNumber: surahNumber),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
