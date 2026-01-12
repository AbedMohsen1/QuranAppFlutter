import 'package:flutter/material.dart';
import 'package:quran_app/home_page.dart';
import 'package:quran_app/home_screen.dart';
import 'package:quran_app/surah_index_page.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/routing/app_routes.dart';

import 'splash_gaza.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.init();

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'AmiriQuran'),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashGazaScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.quranHome: (_) => const QuranHomePage(),
        AppRoutes.surahIndex: (_) => const SurahIndexPage(),
      },
    );
  }
}
