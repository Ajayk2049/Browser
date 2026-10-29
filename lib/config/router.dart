import 'package:go_router/go_router.dart';
import '../features/browser/screens/browser_screen.dart';
import '../features/downloads/downloads.dart';

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
      path: '/downloads',
      name: 'downloads',
      builder: (context, state) => const DownloadsScreen(),
    ),
  ],
);
