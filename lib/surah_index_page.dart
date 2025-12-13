import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/surah_detail_page.dart';
import 'package:audioplayers/audioplayers.dart'; // 🎵 لتشغيل السورة من الفهرس

class SurahIndexPage extends StatefulWidget {
  const SurahIndexPage({super.key});

  @override
  State<SurahIndexPage> createState() => _SurahIndexPageState();
}

class _SurahIndexPageState extends State<SurahIndexPage> {
  int? selectedSurah; // آخر اختيار من هذه الصفحة
  int? lastOpenedSurah; // آخر سورة فُتحت فعليًا من صفحة السورة
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<int> _filtered = List.generate(quran.totalSurahCount, (i) => i + 1);

  // === الصوت لتشغيل السورة من الفهرس ===
  final AudioPlayer _player = AudioPlayer();
  String _reciter = 'ar.alafasy';
  int? _playingSurah; // رقم السورة الجاري تشغيلها من الفهرس
  int? _currentVerse; // الآية الحالية
  bool _isSurahMode = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _search.addListener(_applyFilter);
    _loadReciter();

    // عند انتهاء الآية، انتقل للآية التالية إن كنا في وضع سورة كاملة
    _player.onPlayerComplete.listen((_) async {
      if (!_isSurahMode || _playingSurah == null) return;
      final total = quran.getVerseCount(_playingSurah!);
      final next = (_currentVerse ?? 0) + 1;
      if (next <= total) {
        _currentVerse = next;
        await _playAyah(_playingSurah!, next);
      } else {
        await _stopSurahFromIndex();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('انتهت تلاوة السورة', textAlign: TextAlign.center),
            ),
          );
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  // ================== تحميل التفضيلات ==================
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSurah = prefs.getInt('selected_surah');
      lastOpenedSurah = prefs.getInt('last_opened_surah');
    });

    // مرّر تلقائيًا لآخر سورة فُتحت
    if (lastOpenedSurah != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = lastOpenedSurah! - 1;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          (72.0 * index).clamp(0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _loadReciter() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _reciter = p.getString('reciter') ?? 'ar.alafasy');
  }

  // ================== البحث ==================
  void _applyFilter() {
    final q = _search.text.trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.generate(quran.totalSurahCount, (i) => i + 1);
      } else {
        _filtered = [];
        for (int n = 1; n <= quran.totalSurahCount; n++) {
          final name = quran.getSurahNameArabic(n);
          if (name.contains(q)) _filtered.add(n);
        }
        // لو المستخدم كتب رقم
        final asNum = int.tryParse(q);
        if (asNum != null && asNum >= 1 && asNum <= quran.totalSurahCount) {
          if (!_filtered.contains(asNum)) _filtered.insert(0, asNum);
        }
      }
    });
  }

  Future<void> _saveSelectedSurah(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_surah', surahNumber);
  }

  void _openSurah(BuildContext context, int surahNumber) async {
    await _saveSelectedSurah(surahNumber);
    setState(() => selectedSurah = surahNumber);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SurahDetailPage(surahNumber: surahNumber, fromNavigationBar: false),
      ),
    ).then((_) => _loadPrefs()); // حدّث آخر سورة بعد الرجوع
  }

  // ================== الصوت: حساب الروابط ==================
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
    await _player.stop();
    await _player.play(UrlSource(_ayahUrl(surah, verse)));
  }

  Future<void> _playWholeSurahFromIndex(int surah) async {
    setState(() {
      _isSurahMode = true;
      _playingSurah = surah;
      _currentVerse = 1;
    });
    await _playAyah(surah, 1);
  }

  Future<void> _stopSurahFromIndex() async {
    await _player.stop();
    setState(() {
      _isSurahMode = false;
      _playingSurah = null;
      _currentVerse = null;
    });
  }

  // ================== واجهة الاستخدام ==================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            'فهرس السور',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            if (lastOpenedSurah != null)
              TextButton.icon(
                onPressed: () => _openSurah(context, lastOpenedSurah!),
                icon: const Icon(Icons.history, size: 18, color: Colors.green),
                label: Text(
                  'متابعة: ${quran.getSurahNameArabic(lastOpenedSurah!)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _search,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم السورة أو رقمها…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final surahNumber = _filtered[i];
                  final surahName = quran.getSurahNameArabic(surahNumber);
                  final revelationPlace = quran.getPlaceOfRevelation(
                    surahNumber,
                  );
                  final verseCount = quran.getVerseCount(surahNumber);
                  final juzNumber = quran.getJuzNumber(surahNumber, 1);

                  final isSelected = selectedSurah == surahNumber;
                  final isLast = lastOpenedSurah == surahNumber;

                  final trailingBase = isLast
                      ? const Icon(Icons.bookmark, color: Colors.green)
                      : const Icon(Icons.chevron_left, color: Colors.grey);

                  return Container(
                    color: isSelected
                        ? Colors.red.withOpacity(0.08)
                        : isLast
                        ? Colors.green.withOpacity(0.06)
                        : null,
                    child: ListTile(
                      leading: SizedBox(
                        width: 58,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$surahNumber',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.red : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'جزء $juzNumber',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.red
                                    : Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        surahName,
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'مكان النزول: $revelationPlace • الآيات: $verseCount',
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.grey[700],
                        ),
                      ),

                      // ⬇️ زر تشغيل/إيقاف السورة + الأيقونة الأصلية (بدون تغيير التصميم)
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: _playingSurah == surahNumber
                                ? 'إيقاف التلاوة'
                                : 'تشغيل السورة',
                            icon: Icon(
                              _playingSurah == surahNumber
                                  ? Icons.stop_circle
                                  : Icons.play_circle_fill,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              // حمّل اختيار القارئ إن تغيّر في صفحات أخرى
                              await _loadReciter();
                              if (_playingSurah == surahNumber) {
                                await _stopSurahFromIndex();
                              } else {
                                await _playWholeSurahFromIndex(surahNumber);
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          trailingBase,
                        ],
                      ),

                      onTap: () => _openSurah(context, surahNumber),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
