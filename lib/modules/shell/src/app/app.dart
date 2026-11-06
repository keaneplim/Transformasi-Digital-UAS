import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/theme/app_theme.dart';

import 'app_router.dart';

class JelajahTamanApp extends StatefulWidget {
  const JelajahTamanApp({super.key});

  @override
  State<JelajahTamanApp> createState() => _JelajahTamanAppState();
}

class _JelajahTamanAppState extends State<JelajahTamanApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Jelajah Taman',
        theme: AppTheme.light(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}
