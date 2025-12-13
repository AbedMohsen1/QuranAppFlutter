import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform; // <-- جديد
import 'package:flutter/foundation.dart'; // <-- جديد
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quran_app/reading_progress_service.dart';
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
  int totalPages = 604;
  int currentPage = 0;
  double progress = 0.0;
  String currentSurah = '';

  // Ads
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  Timer? _interstitialTimer;
  DateTime? _lastInterstitialShown;
  bool _isLoadingInterstitial = false;

  // <-- جديد: تعريف المنصات المدعومة للإعلانات
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    loadProgress();

    HijriCalendar.setLocal("ar");
    loadData();
    updateDateTime();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimeOnly());

    _loadAdaptiveBannerAfterLayout();
    _loadInterstitial(); // حضّر أول إعلان بيني
    _startInterstitialAdTimer(); // فحص كل دقيقة، ويعرض فقط إذا مر 3 دقائق وليس في القراءة
  }

  Future<void> loadProgress() async {
    final service = ReadingProgressService();
    final data = await service.loadProgress();
    setState(() {
      currentPage = data['page'];
      currentSurah = data['surah'];
      progress = currentPage / totalPages;
    });
  }

  /// يحمّل بانر تكيفي بعد توفر قياسات الشاشة
  void _loadAdaptiveBannerAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isMobile) return; // <-- جديد: لا تشغّل على Windows/Web

      final widthPx = MediaQuery.of(context).size.width.truncate();
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            widthPx,
          );
      if (!mounted) return;
      if (adaptiveSize == null) return;

      _bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-4905760497560017/8482351944', // HomePage (Banner)
        size: adaptiveSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() {}),
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('فشل تحميل البانر: $error');
          },
        ),
      )..load();
      setState(() {});
    });
  }

  /// تحميل إعلان بيني
  void _loadInterstitial() {
    if (!_isMobile) return; // <-- جديد
    if (_isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5228897328353749/5602200444', // InterstitialAdTimer
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _isLoadingInterstitial = false;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial(); // جهّز اللي بعده
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoadingInterstitial = false;
          _interstitialAd = null;
          debugPrint('فشل تحميل الإعلان البيني: $error');
          // حاول لاحقاً
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// مؤقت لفحص كل دقيقة، ويعرض البيني فقط إذا:
  /// - مر >= 3 دقائق من آخر عرض
  /// - لا يوجد قراءة سورة حالياً (isReadingSurah=false)
  /// - الإعلان جاهز
  void _startInterstitialAdTimer() {
    if (!_isMobile) return; // <-- جديد: لا تشغّل المؤقت على Windows/Web

    _interstitialTimer?.cancel();
    _interstitialTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final isReading = prefs.getBool('isReadingSurah') ?? false;
      final now = DateTime.now();
      final enoughGap =
          _lastInterstitialShown == null ||
          now.difference(_lastInterstitialShown!) >= const Duration(minutes: 3);

      if (!isReading && enoughGap && _interstitialAd != null) {
        _interstitialAd!.show();
        _lastInterstitialShown = DateTime.now();
      } else if (_interstitialAd == null && !_isLoadingInterstitial) {
        _loadInterstitial();
      }
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
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
                          todayAya?['text'] ?? '',
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
                                'يتم حفظ  السورة يلي دخلت لقرائتها تلقائي\n'
                                'لتشغيل صوت القارئ اضغط على الاية \n'
                                'لتغير صوت القارئ اضغط على الأيقونة في اعلى الصفحة\n',
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
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 30,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  _launchURL('https://wa.me/970598063779'),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const FaIcon(
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
                        Text('آخر سورة قرأتها: $currentSurah'),
                        LinearProgressIndicator(value: progress),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% من الختمة',
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

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
