import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/content_repository.dart';

/// Bound in the composition root after the assets are loaded (shell bootstrap).
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError(
    'contentRepositoryProvider must be overridden in the composition root',
  ),
);
