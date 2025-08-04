import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

// أضف هذا الاستيراد في الأعلى
import 'package:google_mobile_ads/google_mobile_ads.dart';

class SurahDetailPage extends StatefulWidget {
  final int surahNumber;
  final bool fromNavigationBar;

  const SurahDetailPage({
    super.key,
    required this.surahNumber,
    this.fromNavigationBar = false,
  });

  @override
  State<SurahDetailPage> createState() => _SurahDetailPageState();
}

class _SurahDetailPageState extends State<SurahDetailPage> {
  int? selectedVerse;
  int tapCount = 0;
  DateTime? lastTapTime;

  // متغير البانر
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    loadSavedVerse();
    saveLastVisitedSurah();
    markReadingStatus(true);

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4905760497560017/7540789458',

      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => setState(() {}),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('فشل تحميل إعلان البانر: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    markReadingStatus(false);
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> markReadingStatus(bool isReading) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isReadingSurah', isReading);
  }

  Future<void> loadSavedVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'selected_verse_${widget.surahNumber}';
    setState(() {
      selectedVerse = prefs.getInt(key);
    });
  }

  Future<void> saveLastVisitedSurah() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_opened_surah', widget.surahNumber);
  }

  Future<void> toggleVerseSelection(int verse) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'selected_verse_${widget.surahNumber}';

    if (selectedVerse == verse) {
      await prefs.remove(key);
      setState(() {
        selectedVerse = null;
      });
    } else {
      await prefs.setInt(key, verse);
      setState(() {
        selectedVerse = verse;
      });
    }
  }

  void handleTap(int verseTextNumber, String verseText) {
    final now = DateTime.now();
    if (lastTapTime == null ||
        now.difference(lastTapTime!) > const Duration(milliseconds: 500)) {
      tapCount = 1;
    } else {
      tapCount += 1;
    }
    lastTapTime = now;

    if (tapCount == 3) {
      Clipboard.setData(ClipboardData(text: verseText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم نسخ الآية", textAlign: TextAlign.center),
        ),
      );
      tapCount = 0;
    } else {
      toggleVerseSelection(verseTextNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    int verseCount = quran.getVerseCount(widget.surahNumber);
    String surahName = quran.getSurahNameArabic(widget.surahNumber);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.green[800],

        automaticallyImplyLeading:
            !widget.fromNavigationBar || widget.surahNumber != 1,
        title: Text(
          'سورة $surahName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/img/quran_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: _bannerAd != null
                          ? _bannerAd!.size.height.toDouble() + 25
                          : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.surahNumber != 9)
                          Image.asset("assets/img/Basmala.png", height: 60),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: RichText(
                            textAlign: TextAlign.justify,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.8,
                                color: Colors.black,
                              ),
                              children: List.generate(verseCount, (index) {
                                int verse = index + 1;
                                String verseText = quran.getVerse(
                                  widget.surahNumber,
                                  verse,
                                );
                                bool isSelected = selectedVerse == verse;

                                return TextSpan(
                                  text: '$verseText ﴿$verse﴾ ',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.red
                                        : Colors.black,
                                    backgroundColor: isSelected
                                        ? Colors.red.withOpacity(0.08)
                                        : null,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => handleTap(verse, verseText),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (widget.surahNumber > 1)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SurahDetailPage(
                                        surahNumber: widget.surahNumber - 1,
                                        fromNavigationBar: false,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'السورة السابقة: ${quran.getSurahNameArabic(widget.surahNumber - 1)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            if (widget.surahNumber < quran.totalSurahCount)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SurahDetailPage(
                                        surahNumber: widget.surahNumber + 1,
                                        fromNavigationBar: false,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'السورة التالية: ${quran.getSurahNameArabic(widget.surahNumber + 1)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // البانر ثابت في الأسفل
          if (_bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
