import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:audioplayers/audioplayers.dart';

bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class AppBootstrap {
  static Future<void> init() async {
    await initializeDateFormatting('ar');
    await _initAds();
    await _initAudio();
  }

  static Future<void> _initAds() async {
    if (isMobile) {
      await MobileAds.instance.initialize();
    }
  }

  static Future<void> _initAudio() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
  }
}
