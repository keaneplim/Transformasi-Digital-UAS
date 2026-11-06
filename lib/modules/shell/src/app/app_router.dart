import 'package:go_router/go_router.dart';

import '../ui/explore_screen.dart';
import '../ui/home_screen.dart';

/// Route table. Modules expose screens/route builders; only `shell` registers routes.
/// Planned named routes: /onboarding, /explore, /poi/:id, /search, /navigate/:dest, /summary, /settings.
GoRouter buildAppRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
      ],
    );
