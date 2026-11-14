import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/providers.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/notify/notify.dart';

import '../state/guide_controller.dart';
import '../state/trigger_alerts.dart';
import '../ui/overlays.dart';
import 'app_router.dart';

class JelajahTamanApp extends ConsumerStatefulWidget {
  const JelajahTamanApp({super.key});

  @override
  ConsumerState<JelajahTamanApp> createState() => _JelajahTamanAppState();
}

class _JelajahTamanAppState extends ConsumerState<JelajahTamanApp> {
  late final GoRouter _router = buildAppRouter();
  TriggerAlerts? _alerts;
  AppLifecycleListener? _lifecycle;

  /// A route asked for by a notification tap while the splash was still showing.
  String? _deferredPath;

  @override
  void initState() {
    super.initState();
    // PB07: only where the notification plugin is bound (the app; not tests or web preview).
    final notifier = ref.read(alertNotifierProvider);
    if (notifier != null) {
      _alerts = TriggerAlerts(
        guide: ref.read(guideProvider),
        notifier: notifier,
        bus: ref.read(eventBusProvider),
        navigate: _navigate,
      );
      _lifecycle = AppLifecycleListener(
        onStateChange: (s) => _alerts?.setVisible(
            s == AppLifecycleState.resumed || s == AppLifecycleState.inactive),
      );
      _router.routerDelegate.addListener(_flushDeferred);
    }
  }

  String get _location => _router.routerDelegate.currentConfiguration.uri.path;

  /// The splash replaces itself with Home/onboarding, which would drop a route pushed now.
  void _navigate(String path) {
    if (_location == '/') {
      _deferredPath = path;
    } else {
      unawaited(_router.push(path));
    }
  }

  void _flushDeferred() {
    final path = _deferredPath;
    if (path == null || _location == '/') return;
    _deferredPath = null;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_router.push(path)));
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_flushDeferred);
    _lifecycle?.dispose();
    _alerts?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(guideProvider.select((d) => d.textScale));
    return MaterialApp.router(
      title: 'Jelajah Taman',
      theme: AppTheme.light(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(context).scale(16) / 16 * scale),
        ),
        // Approaching banner, trigger card and reminders float above every screen.
        child: _RouteListener(
          router: _router,
          builder: (context) => DemoOverlayHost(router: _router, child: child!),
        ),
      ),
    );
  }
}

/// Rebuilds the overlay host when the route changes. go_router notifies during build,
/// so the rebuild is deferred to the next frame when needed.
class _RouteListener extends StatefulWidget {
  const _RouteListener({required this.router, required this.builder});

  final GoRouter router;
  final WidgetBuilder builder;

  @override
  State<_RouteListener> createState() => _RouteListenerState();
}

class _RouteListenerState extends State<_RouteListener> {
  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_changed);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    // go_router can notify while widgets are building (also on first mount, outside a
    // frame), so always rebuild on the next frame.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) setState(() {});
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
