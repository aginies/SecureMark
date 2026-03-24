import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'pages/watermark_page.dart';

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

  AppTheme get appTheme => _appTheme;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('appTheme');
    if (themeIndex != null) {
      setState(() {
        _appTheme = AppTheme.values[themeIndex];
      });
    }
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
      home: const WatermarkPage(),
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
