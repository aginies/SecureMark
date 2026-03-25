import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'pages/watermark_page.dart';
import 'pages/onboarding_page.dart';

enum AppTheme { system, light, dark, amoled }

void main() {
  runApp(const SecureMarkApp());
}

class SecureMarkApp extends StatefulWidget {
  const SecureMarkApp({super.key});

  static SecureMarkAppState of(BuildContext context) =>
      context.findAncestorStateOfType<SecureMarkAppState>()!;

  @override
  State<SecureMarkApp> createState() => SecureMarkAppState();
}

class SecureMarkAppState extends State<SecureMarkApp> {
  AppTheme _appTheme = AppTheme.system;
  bool _isFirstLaunch = false;
  bool _isLoading = true;
  bool _hasCamera = true;
  static const _platform = MethodChannel('secure_mark/sharing');

  AppTheme get appTheme => _appTheme;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('appTheme');
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (themeIndex != null) {
      _appTheme = AppTheme.values[themeIndex];
    }

    await _checkCameraHardware();

    setState(() {
      _isFirstLaunch = isFirstLaunch;
      _isLoading = false;
    });
  }

  Future<void> _checkCameraHardware() async {
    if (kIsWeb) {
      _hasCamera = false;
      return;
    }

    if (Platform.isAndroid) {
      try {
        _hasCamera =
            await _platform.invokeMethod('checkCameraHardware') ?? false;
      } catch (e) {
        _hasCamera = false;
      }
    } else if (Platform.isIOS) {
      _hasCamera = true; // Most iOS devices have cameras
    } else {
      _hasCamera =
          false; // Desktop usually doesn't have a direct camera API here
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    setState(() {
      _isFirstLaunch = false;
    });
  }

  Future<void> setThemeMode(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appTheme', theme.index);
    setState(() {
      _appTheme = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    ThemeData amoledTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        surface: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerHigh: Colors.grey[900],
        surfaceContainerHighest: Colors.grey[850],
        surfaceContainerLow: Colors.black,
        surfaceContainerLowest: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.black,
      cardTheme: const CardThemeData(color: Colors.black),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      useMaterial3: true,
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: _appTheme == AppTheme.amoled
          ? amoledTheme
          : ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
      themeMode: _appTheme == AppTheme.amoled
          ? ThemeMode.dark
          : _getThemeMode(_appTheme),
      home: _isFirstLaunch
          ? OnboardingPage(onDone: _completeOnboarding, hasCamera: _hasCamera)
          : WatermarkPage(hasCamera: _hasCamera),
    );
  }

  ThemeMode _getThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.system:
        return ThemeMode.system;
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
