/// Module `content` (level 1, owner C) — public front door.
///
/// Loads and validates POIs, facilities, routes, park config and the trail graph from
/// assets/content/*.json. Other modules import ONLY this file (rule R1).
library;

export 'src/content_providers.dart';
export 'src/data/asset_content_loader.dart';
export 'src/domain/content_repository.dart';
export 'src/domain/models.dart';
