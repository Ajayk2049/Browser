import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'config/router.dart';
import 'theme/app_theme.dart';
import 'theme/tokens/app_colors.dart';

class BrowserApp extends StatelessWidget {
  const BrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = lightDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: AppColors.brandSeed,
              brightness: Brightness.light,
            );

        final darkScheme = darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: AppColors.brandSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp.router(
          title: 'Dab Browser',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            colorScheme: lightScheme,
            brightness: Brightness.light,
          ),
          darkTheme: AppTheme.build(
            colorScheme: darkScheme,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
        );
      },
    );
  }
}

