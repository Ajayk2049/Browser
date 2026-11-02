import 'package:go_router/go_router.dart';
import '../features/browser/screens/bookmarks_screen.dart';
import '../features/browser/screens/browser_screen.dart';
import '../features/browser/screens/history_screen.dart';
import '../features/downloads/downloads.dart';
import '../features/settings/screens/extensions_screen.dart';
import '../features/settings/screens/homepage_settings_screen.dart';
import '../features/settings/screens/search_engine_settings_screen.dart';
import '../features/settings/settings.dart';

/// App router configuration adhering to rules.md §29.5 and §32.3.
/// Configured with BrowserScreen as initial route.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'browser',
      builder: (context, state) => const BrowserScreen(),
    ),
    GoRoute(
      path: '/bookmarks',
      name: 'bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/downloads',
      name: 'downloads',
      builder: (context, state) => const DownloadsScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/homepage',
      name: 'homepage_settings',
      builder: (context, state) => const HomepageSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/search-engine',
      name: 'search_engine_settings',
      builder: (context, state) => const SearchEngineSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/extensions',
      name: 'extensions_settings',
      builder: (context, state) => const ExtensionsScreen(),
    ),
  ],
);
