import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../ui/arrived_screen.dart';
import '../ui/main_shell.dart';
import '../ui/navigation_screen.dart';
import '../ui/now_playing_screen.dart';
import '../ui/onboarding_screen.dart';
import '../ui/overlays.dart';
import '../ui/poi_detail_screen.dart';
import '../ui/scan_screen.dart';
import '../ui/settings_screen.dart';
import '../ui/setup_screen.dart';
import '../ui/splash_screen.dart';
import '../ui/summary_screen.dart';

/// Route table. Only `shell` registers routes.
GoRouter buildAppRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
            path: '/welcome',
            pageBuilder: (c, s) => _fade(s, const OnboardingScreen())),
        GoRoute(
            path: '/setup',
            pageBuilder: (c, s) => _slide(s, const SetupScreen())),
        GoRoute(
            path: '/home', pageBuilder: (c, s) => _fade(s, const MainShell())),
        GoRoute(
          path: '/poi/:id',
          pageBuilder: (c, s) => _slide(
              s,
              PoiDetailScreen(
                id: s.pathParameters['id']!,
                heroSuffix: s.uri.queryParameters['hero'] ?? '',
              )),
        ),
        GoRoute(
          path: '/play/:id',
          pageBuilder: (c, s) =>
              _rise(s, NowPlayingScreen(id: s.pathParameters['id']!)),
        ),
        GoRoute(
            path: '/navigate',
            pageBuilder: (c, s) => _fade(s, const NavigationScreen())),
        GoRoute(
            path: '/arrived',
            pageBuilder: (c, s) => _rise(s, const ArrivedScreen())),
        GoRoute(
            path: '/scan', pageBuilder: (c, s) => _rise(s, const ScanScreen())),
        GoRoute(
            path: '/summary',
            pageBuilder: (c, s) => _rise(s, const SummaryScreen())),
        GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => _slide(s, const SettingsScreen())),
      ],
    );

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (context, a, b, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: JTMotion.out),
        child: child,
      ),
    );

/// Push: slides in from the right with a fade; the page underneath drifts back a little.
CustomTransitionPage<void> _slide(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, a, b, child) {
        final t = CurvedAnimation(parent: a, curve: JTMotion.emphasized);
        final back = CurvedAnimation(parent: b, curve: JTMotion.emphasized);
        return SlideTransition(
          position:
              Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(t),
          child: FadeTransition(
            opacity: t,
            child: SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0))
                  .animate(back),
              child: child,
            ),
          ),
        );
      },
    );

/// Modal-feeling screens rise from the bottom.
CustomTransitionPage<void> _rise(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      transitionsBuilder: (context, a, b, child) {
        final t = CurvedAnimation(parent: a, curve: JTMotion.emphasized);
        return SlideTransition(
          position:
              Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(t),
          child: FadeTransition(opacity: t, child: child),
        );
      },
    );
