import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/reading_progress_service.dart';
import 'package:quran_app/surah_detail_page.dart';
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

  // ===== خطة الختمة =====
  ReadingStatus? _khatma;
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _reminderBusy = false;

  // ===== Ads =====
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  Timer? _interstitialTimer;
  DateTime? _lastInterstitialShown;
  bool _isLoadingInterstitial = false;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();

    HijriCalendar.setLocal("ar");
    loadData();
    updateDateTime();

    // ReadingProgressService.ensureInitialized().then((_) => _initKhatma());
    _initKhatma();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimeOnly());

    _loadAdaptiveBannerAfterLayout();
    _loadInterstitial();
    _startInterstitialAdTimer();
  }

  // ====== Banner ======
  void _loadAdaptiveBannerAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isMobile) return;

      final widthPx = MediaQuery.of(context).size.width.truncate();
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            widthPx,
          );

      if (!mounted) return;
      if (adaptiveSize == null) return;

      _bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-5228897328353749/5750352175',
        // adUnitId: 'ca-app-pub-3940256099942544/2435281174',
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

  // ====== Interstitial ======
  void _loadInterstitial() {
    if (!_isMobile) return;
    if (_isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5228897328353749/5602200444',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _isLoadingInterstitial = false;
          _interstitialAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
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
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  void _startInterstitialAdTimer() {
    if (!_isMobile) return;

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

  // ====== Lifecycle ======
  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    timer.cancel();
    super.dispose();
  }

  // ====== Dates/Time ======
  void updateDateTime() {
    final now = DateTime.now();
    gregorianDate = DateFormat('d MMMM yyyy', 'ar').format(now);
    final hijri = HijriCalendar.fromDate(now);
    hijriDate = '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} هـ';
    currentTime = DateFormat('hh:mm:ss a', 'ar').format(now);
  }

  void updateTimeOnly() {
    final now = DateTime.now();
    setState(() {
      currentTime = DateFormat('hh:mm:ss a', 'ar').format(now);
    });

    // افحص التذكير مرة بالدقيقة (على الثانية 0)
    if (now.second == 0) {
      _maybeShowReminder(now);
    }
  }

  // ====== Load Aya/Hadith ======
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

  // ====== Khatma ======
  Future<void> _initKhatma() async {
    final st = await ReadingProgressService.getStatus();

    final enabled = await ReadingProgressService.getReminderEnabled();
    final hhmm = await ReadingProgressService.getReminderTimeHHMM();
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 21;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    if (!mounted) return;
    setState(() {
      _khatma = st;
      _reminderEnabled = enabled;
      _reminderTime = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    });
  }

  Future<void> _reloadKhatma() async {
    final st = await ReadingProgressService.getStatus();
    if (!mounted) return;
    setState(() => _khatma = st);
  }

  Future<void> _continueReading() async {
    final st = _khatma;
    if (st == null || st.lastSurah == null || st.lastVerse == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('افتح سورة واضغط على آية لحفظ موضع القراءة أولًا'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_verse_${st.lastSurah}', st.lastVerse!);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailPage(
          surahNumber: st.lastSurah!,
          fromNavigationBar: false,
        ),
      ),
    );

    await _reloadKhatma();
  }

  Future<void> _changePlanDays() async {
    final controller = TextEditingController(
      text: (_khatma?.goalDays ?? 30).toString(),
    );
    final days = await showDialog<int?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خطة الختمة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'مثال: 30 يوم',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (days == null) return;
    await ReadingProgressService.setGoalDays(days);
    await _reloadKhatma();
  }

  Future<void> _resetKhatma() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة ضبط الختمة؟'),
        content: const Text('سيتم تصفير التقدم اليومي والختمة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ReadingProgressService.resetKhatma();
    await _reloadKhatma();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;

    final hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await ReadingProgressService.setReminderTimeHHMM(hhmm);

    if (!mounted) return;
    setState(() => _reminderTime = picked);
  }

  Future<void> _toggleReminder(bool v) async {
    await ReadingProgressService.setReminderEnabled(v);
    if (!mounted) return;
    setState(() => _reminderEnabled = v);
  }

  Future<void> _maybeShowReminder(DateTime now) async {
    if (_reminderBusy || !_reminderEnabled) return;

    if (now.hour != _reminderTime.hour || now.minute != _reminderTime.minute)
      return;

    _reminderBusy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final isReading = prefs.getBool('isReadingSurah') ?? false;
      if (isReading) return;

      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastShown = await ReadingProgressService.getReminderLastShownDate();
      if (lastShown == todayKey) return;

      await ReadingProgressService.setReminderLastShownDate(todayKey);

      // حدّث الحالة قبل العرض
      final st = await ReadingProgressService.getStatus();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('⏰ تذكير ورد اليوم'),
          content: Text(
            'اليوم قرأت: ${st.todayRead} آية من هدف ${st.dailyTarget} آية.\n\nاضغط "متابعة" للعودة لآخر موضع.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقًا'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _continueReading();
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
    } finally {
      _reminderBusy = false;
    }
  }

  Widget _buildKhatmaCard() {
    final st = _khatma;
    if (st == null) {
      return Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('جاري تحميل خطة الختمة…', textAlign: TextAlign.center),
        ),
      );
    }

    final loc = (st.lastSurah != null && st.lastVerse != null)
        ? 'آخر موضع: سورة ${quran.getSurahNameArabic(st.lastSurah!)} • آية ${st.lastVerse}'
        : 'لم يتم حفظ موضع بعد (اضغط على آية داخل السورة لحفظ موضع القراءة).';

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📖 خطة الختمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(loc, textAlign: TextAlign.right),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: st.percent),
            const SizedBox(height: 8),
            Text('تقدم اليوم: ${st.todayRead} / ${st.dailyTarget} آية'),
            Text('الخطة: ختمة خلال ${st.goalDays} يوم'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _continueReading,
                    child: const Text('متابعة'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _changePlanDays,
                  child: const Text('تعديل الخطة'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetKhatma,
                child: const Text('إعادة ضبط الختمة'),
              ),
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.notifications_active, size: 18),
                const SizedBox(width: 8),
                const Text('تذكير يومي'),
                const Spacer(),
                Switch(value: _reminderEnabled, onChanged: _toggleReminder),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pickReminderTime,
                icon: const Icon(Icons.schedule),
                label: Text('الوقت: ${_reminderTime.format(context)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== UI ======
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
                        const SizedBox(height: 14),

                        // ✅ كرت الختمة
                        _buildKhatmaCard(),
                        const SizedBox(height: 10),

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
                                '✅ لحفظ موضع القراءة: اضغط على الآية مرة واحدة\n'
                                'يتم حفظ السورة التي دخلت لقراءتها تلقائيًا\n'
                                'لتشغيل صوت القارئ اضغط على الآية\n'
                                'لتغيير صوت القارئ اضغط على الأيقونة في أعلى الصفحة\n',
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
                      ],
                    ),
                  ),
                ),
                if (_bannerAd != null)
                  SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd!),
                      ),
                    ),
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
