import 'package:flutter/material.dart';
import 'config/router.dart';
import 'features/settings/services/appearance_settings_service.dart';
import 'theme/app_theme.dart';
import 'theme/tokens/app_colors.dart';

class BrowserApp extends StatelessWidget {
  const BrowserApp({super.key});

  static final ThemeData _lightTheme = AppTheme.build(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: Brightness.light,
    ),
    brightness: Brightness.light,
  );

  static final ThemeData _darkTheme = AppTheme.build(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: Brightness.dark,
    ),
    brightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppearanceSettingsService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Dab Browser',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: AppearanceSettingsService.instance.themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}

