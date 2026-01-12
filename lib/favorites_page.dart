import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/favorites_service.dart';
import 'package:quran_app/reading_progress_service.dart';
import 'package:quran_app/surah_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _search = TextEditingController();
  List<FavItem> _items = [];
  List<FavItem> _filtered = [];

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5228897328353749/5131405070',

      // adUnitId: 'ca-app-pub-3940256099942544/2435281174',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final items = await FavoritesService.getAll();
    if (!mounted) return;

    setState(() {
      _items = items;
      _filtered = items;
      _loading = false;
    });
  }

  void _applyFilter() {
    final q = _search.text.trim();
    if (q.isEmpty) {
      setState(() => _filtered = _items);
      return;
    }
    setState(() {
      _filtered = _items.where((e) {
        return e.surahName.contains(q) ||
            e.verseText.contains(q) ||
            (e.note ?? '').contains(q) ||
            e.verse.toString() == q ||
            e.surah.toString() == q;
      }).toList();
    });
  }

  Future<void> _openFav(FavItem item) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('selected_verse_${item.surah}', item.verse);

    await ReadingProgressService.saveProgress(
      surah: item.surah,
      verse: item.verse,
    );

    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SurahDetailPage(surahNumber: item.surah, fromNavigationBar: false),
      ),
    );

    // 🔥 إذا صار تغيير بالمفضلة
    if (changed == true) {
      await _load(); // يحدث القائمة فورًا
    }

    // ✅ تحديث المفضلة مباشرة بعد الرجوع
    await _load();
  }

  Future<void> _editNote(FavItem item) async {
    final controller = TextEditingController(text: item.note ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ملاحظة على: ${item.surahName} • آية ${item.verse}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظتك…',
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
    await FavoritesService.updateNote(item.surah, item.verse, result);
    await _load();
  }

  Future<void> _deleteFav(FavItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف من المفضلة؟'),
        content: Text('${item.surahName} • آية ${item.verse}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await FavoritesService.remove(item.surah, item.verse);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    setState(() {});
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text('المفضلة'),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _load(); // 🔥 تحديث الشاشة
              },
            ),
          ],
        ),

        // 🔥 البانر هنا (أفضل مكان)
        bottomNavigationBar: (_isBannerLoaded && _bannerAd != null)
            ? SafeArea(
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              )
            : null,

        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: TextField(
                      controller: _search,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'ابحث (سورة/آية/نص/ملاحظة)…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('لا توجد عناصر في المفضلة بعد.'),
                          )
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final item = _filtered[i];
                              final title = item.surahName.isNotEmpty
                                  ? item.surahName
                                  : quran.getSurahNameArabic(item.surah);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  onTap: () => _openFav(item),
                                  title: Text(
                                    '$title • آية ${item.verse}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Text(
                                        item.verseText,
                                        textAlign: TextAlign.right,
                                      ),
                                      if ((item.note ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '📝 ${item.note}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Wrap(
                                    spacing: 6,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_note),
                                        onPressed: () => _editNote(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteFav(item),
                                      ),
                                    ],
                                  ),
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
