import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/favorites_service.dart';
import 'package:quran_app/reading_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show Platform; // <-- جديد
import 'package:flutter/foundation.dart'; // <-- جديد

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
  late int _currentSurah;

  int? selectedVerse; // الآية المحفوظة/المعلَّمة
  BannerAd? _bannerAd; // بانر تكيفي

  // الصوت
  final AudioPlayer _player = AudioPlayer();
  bool _isSurahMode = false; // تشغيل السورة كاملة
  int? _currentVerseInSurah; // مؤشر الآية في وضع السورة
  int? _playingVerse; // الآية التي تُشغَّل الآن

  // <-- جديد: تعريف المنصّات المدعومة للإعلانات
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final Map<String, String> _reciters = const {
    'ar.alafasy': 'العفاسي',
    'ar.husary': 'الحصري',
    'ar.minshawi': 'المنشاوي',
    'ar.mahermuaiqly': 'ماهر المعيقلي',
  };
  String _reciter = 'ar.alafasy';

  @override
  void initState() {
    super.initState();
    _loadReciter();
    _loadSavedVerse();
    _saveLastVisitedSurah();
    _markReadingStatus(true);
    _loadAdaptiveBannerAfterLayout();
    _currentSurah = widget.surahNumber;
    // عند انتهاء المقطع
    _player.onPlayerComplete.listen((_) async {
      if (!mounted) return;
      if (!_isSurahMode) return;

      final maxVerse = quran.getVerseCount(_currentSurah);
      final nextVerse = (_currentVerseInSurah ?? 0) + 1;

      if (nextVerse <= maxVerse) {
        // نفس السورة
        _currentVerseInSurah = nextVerse;
        await _playAyah(_currentSurah, nextVerse);
      } else {
        // 🔥 انتقل للسورة التالية
        final nextSurah = _currentSurah + 1;

        if (nextSurah <= quran.totalSurahCount) {
          setState(() {
            _currentSurah = nextSurah;
            _currentVerseInSurah = 1;
          });

          await _playAyah(_currentSurah, 1);
        } else {
          // انتهى القرآن
          await _stopSurah();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('انتهت تلاوة القرآن الكريم')),
            );
          }
        }
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.stopped) {
        setState(() => _playingVerse = null);
      }
    });
  }

  @override
  void dispose() {
    _markReadingStatus(false);
    _bannerAd?.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  // ================== تفضيل القارئ ==================
  Future<void> _loadReciter() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _reciter = p.getString('reciter') ?? 'ar.alafasy');
  }

  Future<void> _saveReciter(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('reciter', v);
  }

  Future<void> _changeReciter(String v) async {
    setState(() => _reciter = v);
    await _saveReciter(v);
    if (_isSurahMode && _currentVerseInSurah != null) {
      _playAyah(widget.surahNumber, _currentVerseInSurah!);
    }
  }

  // ================== تحديد/حفظ آية ==================
  Future<void> _loadSavedVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'selected_verse_${widget.surahNumber}';
    setState(() => selectedVerse = prefs.getInt(key));
  }

  Future<void> _toggleVerseSelection(int verse) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'selected_verse_${widget.surahNumber}';

    if (selectedVerse == verse) {
      await prefs.remove(key);
      setState(() => selectedVerse = null);
    } else {
      await prefs.setInt(key, verse);
      setState(() => selectedVerse = verse);

      await ReadingProgressService.saveProgress(
        surah: widget.surahNumber,
        verse: verse,
      );
    }
  }

  Future<void> _saveLastVisitedSurah() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_opened_surah', widget.surahNumber);
  }

  Future<void> _markReadingStatus(bool isReading) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isReadingSurah', isReading);
  }

  // ================== الصوت ==================
  int _globalAyahIndex(int surah, int verse) {
    int sum = 0;
    for (int s = 1; s < surah; s++) {
      sum += quran.getVerseCount(s);
    }
    return sum + verse; // 1..6236
  }

  String _ayahUrl(int surah, int verse) {
    final g = _globalAyahIndex(surah, verse);
    return 'https://cdn.islamic.network/quran/audio/128/$_reciter/$g.mp3';
  }

  Future<void> _playAyah(int surah, int verse) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(_ayahUrl(surah, verse)));
      setState(() => _playingVerse = verse);
    } catch (e) {
      debugPrint('فشل تشغيل الآية: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل التلاوة')));
      }
    }
  }

  Future<void> _playSurahFrom(int startVerse) async {
    _isSurahMode = true;
    _currentVerseInSurah = startVerse;
    await _playAyah(widget.surahNumber, startVerse);
  }

  Future<void> _stopSurah() async {
    _isSurahMode = false;
    _currentVerseInSurah = null;
    await _player.stop();
    setState(() => _playingVerse = null);
  }

  Future<void> _togglePlayFullSurah() async {
    if (_isSurahMode) {
      await _stopSurah();
    } else {
      await _playSurahFrom(1);
    }
  }

  // ================== BottomSheet على الآية ==================
  Future<void> _showAyahActions(int verse, String verseText) async {
    final isSaved = selectedVerse == verse;
    final surahName = quran.getSurahNameArabic(widget.surahNumber);

    final favItem = await FavoritesService.getItem(widget.surahNumber, verse);
    final isFav = favItem != null;
    final note = favItem?.note;

    if (!mounted) return;

    void openNoteDialog() async {
      final controller = TextEditingController(text: note ?? '');
      final result = await showDialog<String?>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('ملاحظة على: $surahName • آية $verse'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظتك… (سيتم حفظ الآية في المفضلة)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (result == null) return;

      // الملاحظة = إضافة/تحديث في المفضلة
      await FavoritesService.addOrUpdate(
        surah: widget.surahNumber,
        verse: verse,
        surahName: surahName,
        verseText: verseText,
        note: result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملاحظة في المفضلة')),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('تشغيل تلاوة الآية'),
              subtitle: Text('الآية رقم $verse'),
              onTap: () async {
                Navigator.pop(context);
                await _playAyah(_currentSurah, verse);
                if (_isSurahMode) {
                  setState(() {
                    _isSurahMode = false;
                    _currentVerseInSurah = null;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('تشغيل السورة من هذه الآية'),
              subtitle: Text('من الآية رقم $verse حتى نهاية السورة'),
              onTap: () async {
                Navigator.pop(context);
                await _playSurahFrom(verse);
              },
            ),
            ListTile(
              leading: Icon(
                isSaved ? Icons.bookmark_remove : Icons.bookmark_add,
              ),
              title: Text(isSaved ? 'إزالة العلامة' : 'حفظ موضع القراءة'),
              onTap: () async {
                await _toggleVerseSelection(verse);
                Navigator.pop(context);
              },
            ),

            const Divider(),

            ListTile(
              leading: Icon(isFav ? Icons.favorite : Icons.favorite_border),
              title: Text(isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
              subtitle: (note != null && note.trim().isNotEmpty)
                  ? Text('ملاحظة: $note')
                  : null,
              onTap: () async {
                Navigator.pop(context);
                if (isFav) {
                  await FavoritesService.remove(widget.surahNumber, verse);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت الإزالة من المفضلة')),
                    );
                  }
                } else {
                  await FavoritesService.addOrUpdate(
                    surah: widget.surahNumber,
                    verse: verse,
                    surahName: surahName,
                    verseText: verseText,
                    note: note,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت الإضافة للمفضلة')),
                    );
                  }
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('إضافة/تعديل ملاحظة'),
              onTap: () {
                Navigator.pop(context);
                openNoteDialog();
              },
            ),

            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ نص الآية'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: verseText));
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
                }
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // ================== إعلان بانر تكيفي ==================
  // ignore: unused_field
  bool _isBannerLoaded = false;

  void _loadAdaptiveBannerAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isMobile) return; // <-- جديد: لا تعمل على Windows/Web
      if (!mounted) return;

      final widthPx = MediaQuery.of(context).size.width.truncate();
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            widthPx,
          );
      if (!mounted || adaptiveSize == null) return;

      _bannerAd = BannerAd(
        adUnitId:
            'ca-app-pub-5228897328353749/6332806101', // SurahDetail Banner
        // adUnitId: 'ca-app-pub-3940256099942544/2435281174',
        size: adaptiveSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() => _isBannerLoaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('❌ Banner failed: ${error.code} - ${error.message}');
          },
        ),
      )..load();
      if (mounted) setState(() {});
    });
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final int verseCount = quran.getVerseCount(widget.surahNumber);
    final String surahName = quran.getSurahNameArabic(widget.surahNumber);

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
        actions: [
          PopupMenuButton<String>(
            tooltip: 'اختيار القارئ',
            icon: const Icon(Icons.record_voice_over, color: Colors.white),
            onSelected: _changeReciter,
            itemBuilder: (context) => _reciters.entries.map((e) {
              final selected = _reciter == e.key;
              return PopupMenuItem<String>(
                value: e.key,
                child: Row(
                  children: [
                    if (selected)
                      const Icon(Icons.check, size: 18, color: Colors.green),
                    if (selected) const SizedBox(width: 6),
                    Text(e.value),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            tooltip: _isSurahMode ? 'إيقاف تلاوة السورة' : 'تشغيل السورة كاملة',
            icon: Icon(
              _isSurahMode ? Icons.stop_circle : Icons.play_circle_fill,
              color: Colors.white,
            ),
            onPressed: _togglePlayFullSurah,
          ),
        ],
      ),
      bottomNavigationBar: (_isBannerLoaded && _bannerAd != null)
          ? SafeArea(
              child: SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: Stack(
        children: [
          // خلفية
          Container(
            decoration: const BoxDecoration(
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
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
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
                              children: List<InlineSpan>.generate(verseCount, (
                                index,
                              ) {
                                final verse = index + 1;
                                final verseText = quran.getVerse(
                                  widget.surahNumber,
                                  verse,
                                );
                                final isSelected = selectedVerse == verse;
                                final isPlaying = _playingVerse == verse;

                                // نمط النص بحسب الحالة
                                final TextStyle style = TextStyle(
                                  color: isSelected ? Colors.red : Colors.black,
                                  backgroundColor: isSelected
                                      ? Colors.red.withOpacity(0.08)
                                      : (isPlaying
                                            ? Colors.lightBlueAccent
                                                  .withOpacity(0.12)
                                            : null),
                                  decoration: isPlaying
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationStyle: isPlaying
                                      ? TextDecorationStyle.wavy
                                      : TextDecorationStyle.solid,
                                  decorationColor: isPlaying
                                      ? Colors.blueAccent
                                      : null,
                                  decorationThickness: isPlaying ? 2.0 : null,
                                  fontWeight: isPlaying
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  shadows: isPlaying
                                      ? [
                                          Shadow(
                                            color: Colors.blueAccent
                                                .withOpacity(0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                );

                                // الـ span الأساسي للنص + رقم الآية
                                final mainSpan = TextSpan(
                                  text: '$verseText ﴿$verse﴾',
                                  style: style,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showAyahActions(verse, verseText);
                                    },
                                );

                                // إن كانت الآية تعمل الآن، أضف أيقونة صغيرة بعد الرقم
                                if (isPlaying) {
                                  return TextSpan(
                                    children: [
                                      mainSpan,
                                      const TextSpan(text: ' '),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                start: 2,
                                              ),
                                          child: Icon(
                                            Icons.graphic_eq,
                                            size: 16,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' '),
                                    ],
                                  );
                                } else {
                                  return TextSpan(
                                    children: [
                                      mainSpan,
                                      const TextSpan(text: ' '),
                                    ],
                                  );
                                }
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
        ],
      ),
    );
  }
}
