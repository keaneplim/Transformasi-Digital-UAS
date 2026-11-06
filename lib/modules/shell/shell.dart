/// Module `shell` (level 5, owners C onboarding/Home/Settings, B Explore/summary + integration, A session wiring) — public front door.
///
/// App entry, composition root (the only place bindings happen, rule R8), route table,
/// onboarding UI01, Home UI02, Explore, session summary UI14, Settings UI15, debug menu. May import every module's public file.
library;

export 'src/app/app.dart';
export 'src/app/composition_root.dart';
