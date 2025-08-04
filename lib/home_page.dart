import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  List<dynamic> ayaList = [];
  List<dynamic> hadithList = [];
  Map<String, dynamic>? todayAya;
  String? todayHadith;

  String hijriDate = '';
  String gregorianDate = '';
  String currentTime = '';
  late Timer timer;
  BannerAd? _bannerAdTop;
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  Timer? _interstitialTimer;

  @override
  void initState() {
    super.initState();
    HijriCalendar.setLocal("ar");
    loadData();
    updateDateTime();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimeOnly());

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4905760497560017/8482351944',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => setState(() {}),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('فشل تحميل الإعلان السفلي: $error');
        },
      ),
    )..load();

    _startInterstitialAdTimer();
  }

  void _startInterstitialAdTimer() {
    _interstitialTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      final prefs = await SharedPreferences.getInstance();
      bool isReading = prefs.getBool('isReadingSurah') ?? false;
      if (!isReading) {
        InterstitialAd.load(
          adUnitId: 'ca-app-pub-4905760497560017/6793865755',
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (InterstitialAd ad) {
              _interstitialAd = ad;
              ad.show();
            },
            onAdFailedToLoad: (LoadAdError error) {
              print('فشل تحميل الإعلان البيني: $error');
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAdTop?.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    timer.cancel();
    super.dispose();
  }

  void updateDateTime() {
    final now = DateTime.now();
    gregorianDate = DateFormat('d MMMM yyyy', 'ar').format(now);
    final hijri = HijriCalendar.fromDate(now);
    hijriDate = '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} هـ';
    currentTime = DateFormat('hh:mm:ss a', 'ar').format(now);
  }

  void updateTimeOnly() {
    setState(() {
      currentTime = DateFormat('hh:mm:ss a', 'ar').format(DateTime.now());
    });
  }

  Future<void> loadData() async {
    final ayaData = await rootBundle.loadString('assets/json/aya.json');
    final hadithData = await rootBundle.loadString('assets/json/hadith.json');

    final ayaJson = json.decode(ayaData);
    final hadithJson = json.decode(hadithData);

    setState(() {
      ayaList = ayaJson;
      hadithList = hadithJson;
      int index = DateTime.now().day % ayaList.length;
      todayAya = ayaList[index];
      todayHadith = hadithList[index];
      updateDateTime();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("القرآن الكريم"),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: ayaList.isEmpty || hadithList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          ' الوقت الآن: $currentTime',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' التاريخ الميلادي: $gregorianDate',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          ' التاريخ الهجري: $hijriDate',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        _buildCard(
                          "آية اليوم",
                          todayAya?['text'],
                          'سورة ${todayAya?['surah']} - آية ${todayAya?['ayah']}',
                        ),
                        const SizedBox(height: 10),
                        _buildCard("حديث اليوم", todayHadith ?? '', ''),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Text(
                                '📌 ملاحظة عزيزي القارئ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                '✅ .لحفظ موضع القراءة: اضغط على الآية مرة واحدة\n'
                                '🗑️ .لحذف العلامة: اضغط على نفس الآية مرة ثانية\n'
                                '📋 .لنسخ نص الآية: اضغط على الآية 3 مرات متتالية',
                                style: TextStyle(fontSize: 15.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 30,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  _launchURL('https://wa.me/970598063779'),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.facebook,
                                size: 30,
                                color: Colors.blue,
                              ),
                              onPressed: () => _launchURL(
                                'https://www.facebook.com/share/1AmMZwFifb/',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_bannerAd != null)
                  SizedBox(
                    width: double.infinity,
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
    );
  }

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'لا يمكن فتح الرابط $url';
    }
  }

  Widget _buildCard(String title, String content, String subText) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (subText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subText, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
