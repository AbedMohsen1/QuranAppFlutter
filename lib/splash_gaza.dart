import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quran_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashGazaScreen extends StatefulWidget {
  const SplashGazaScreen({super.key});

  @override
  State<SplashGazaScreen> createState() => _SplashGazaScreenState();
}

class _SplashGazaScreenState extends State<SplashGazaScreen> {
  int secondsLeft = 10;
  Timer? countdownTimer;

  static const _prefsKey = 'gaza_splash_last_shown'; // مفتاح التخزين

  @override
  void initState() {
    super.initState();
    _decideFlow();
  }

  // مفتاح اليوم (سنة-شهر-يوم) بدون حزم إضافية
  String _todayKey() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _decideFlow() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_prefsKey);
    final today = _todayKey();

    if (last == today) {
      // انعرضت اليوم بالفعل → ادخل مباشرة
      _goHome();
    } else {
      // أول مرة اليوم → اعرض مع العداد، وبعد الانتقال خزّن تاريخ اليوم
      _startCountdown(
        onFinish: () async {
          await prefs.setString(_prefsKey, today);
          _goHome();
        },
      );
    }
  }

  void _startCountdown({required Future<void> Function() onFinish}) {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (secondsLeft > 1) {
        setState(() => secondsLeft--);
      } else {
        timer.cancel();
        await onFinish();
      }
    });
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "دعاء لأهلنا في غزة ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.7,
                ),
              ),
              Image.asset("assets/img/gaza_dua.png", height: 110),
              const SizedBox(height: 20),
              const Text(
                "اللهم يا قوي يا عزيز، كن لأهل غزة سندًا ونصيرًا، اللهم احفظهم بحفظك واكفهم شر الأعداء، اللهم اربط على قلوبهم وثبت أقدامهم وانصرهم على من عاداهم، وارفع عنهم البلاء والشدائد، وارحم شهداءهم واشف جرحاهم وفك أسرهم، وأبدل خوفهم أمنًا وحزنهم فرحًا، يا أرحم الراحمين.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 40),
              // عداد تنازلي واضح
              Text(
                "الانتقال خلال $secondsLeft ثانية",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
