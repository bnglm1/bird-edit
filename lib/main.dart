import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/account_service.dart';
import 'services/ad_service.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Oyun dikey tasarlandı
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  try {
    await SoundService.instance.init();
  } catch (e) {
    if (kDebugMode) debugPrint('SoundService init error: $e');
  }

  // Reklam SDK'sı açılışı geciktirmesin
  unawaited(AdService.instance.init());

  // Auth değişimini dinlemeye başla
  AccountService.start();

  runApp(const KelimeUstasiApp());
}

class KelimeUstasiApp extends StatelessWidget {
  const KelimeUstasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelime Ustası',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
