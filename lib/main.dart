import 'dart:io' show Platform; // <-- جديد
import 'package:flutter/foundation.dart'; // <-- جديد
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:quran_app/home_page.dart';
import 'package:quran_app/splash_gaza.dart';
import 'package:quran_app/surah_index_page.dart';

// <-- جديد: حارس لمنصات الموبايل فقط
bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<void> _initAdsIfSupported() async {
  // <-- جديد
  if (_isMobile) {
    await MobileAds.instance.initialize();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التاريخ بالعربية
  await initializeDateFormatting('ar');

  // الإعلانات (فقط على Android/iOS)
  await _initAdsIfSupported(); // <-- بدل MobileAds.instance.initialize()

  // ✅ إعداد سياق الصوت لتقليل أخطاء التشغيل على Android/iOS
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
        isSpeakerphoneOn: false,
        stayAwake: false,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Uthman'),
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,

      // ابدأ بالسبلاش
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashGazaScreen(),
        '/home': (context) => const HomeScreen(),
        '/quranHome': (context) => const QuranHomePage(),
        '/surahIndex': (context) => const SurahIndexPage(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<Widget> screens = const [QuranHomePage(), SurahIndexPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: screens[selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الصفحة الرئيسية',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'الفهرس'),
        ],
      ),
    );
  }
}
