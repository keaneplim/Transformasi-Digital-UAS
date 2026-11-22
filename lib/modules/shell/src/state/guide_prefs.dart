import 'dart:convert';

import 'package:jelajah_taman/core/core.dart';

/// The visitor's choices that must survive closing the app (#32, T31, PB18): onboarding done,
/// Settings (UI15) and the Home choices (interests, route). Stored on the phone only (NG05),
/// as one JSON value under [key]; shell owns the `guide.*` keys of the [KeyValueStore] (R6).
///
/// The session itself (visits, walk, steps) is kept by `session`, the app mode under
/// `app_mode`; neither is here.
class GuidePrefs {
  const GuidePrefs({
    this.onboarded = false,
    this.autoPlay = false,
    this.voiceGuidance = true,
    this.vibration = true,
    this.hydrationMin = 45,
    this.textScale = 1.0,
    this.weightKg,
    this.interests = const {'sejarah', 'alam'},
    this.routeId = 'santai',
  });

  static const key = 'guide.prefs';

  /// Settings offers these; anything else read back falls back to the default.
  static const hydrationChoices = {0, 30, 45, 60};
  static const textScaleChoices = [1.0, 1.15, 1.3];
  static const minWeightKg = 30.0;
  static const maxWeightKg = 130.0;

  final bool onboarded;
  final bool autoPlay;
  final bool voiceGuidance;
  final bool vibration;

  /// Minutes; 0 = off.
  final int hydrationMin;
  final double textScale;

  /// Optional (D11); null = not given, the kcal estimate uses 60 kg.
  final double? weightKg;
  final Set<String> interests;
  final String routeId;

  Map<String, Object?> toJson() => {
        'v': 1,
        'onboarded': onboarded,
        'auto_play': autoPlay,
        'voice_guidance': voiceGuidance,
        'vibration': vibration,
        'hydration_min': hydrationMin,
        'text_scale': textScale,
        'weight_kg': weightKg,
        'interests': interests.toList()..sort(),
        'route_id': routeId,
      };

  /// Reads what [toJson] wrote. Each value is checked on its own: one bad or unknown value
  /// falls back to its default instead of losing every preference.
  factory GuidePrefs.fromJson(Map<String, Object?> j,
      {GuidePrefs defaults = const GuidePrefs()}) {
    bool flag(String k, bool d) => j[k] is bool ? j[k]! as bool : d;
    final hydration = j['hydration_min'];
    final scale = j['text_scale'];
    final weight = j['weight_kg'];
    final interests = j['interests'];
    final route = j['route_id'];
    return GuidePrefs(
      onboarded: flag('onboarded', defaults.onboarded),
      autoPlay: flag('auto_play', defaults.autoPlay),
      voiceGuidance: flag('voice_guidance', defaults.voiceGuidance),
      vibration: flag('vibration', defaults.vibration),
      hydrationMin: hydration is int && hydrationChoices.contains(hydration)
          ? hydration
          : defaults.hydrationMin,
      textScale: scale is num && textScaleChoices.contains(scale.toDouble())
          ? scale.toDouble()
          : defaults.textScale,
      weightKg: weight is num && weight >= minWeightKg && weight <= maxWeightKg
          ? weight.toDouble()
          : null,
      interests: interests is List
          ? {
              for (final i in interests)
                if (i is String) i
            }
          : defaults.interests,
      routeId: route is String && route.isNotEmpty ? route : defaults.routeId,
    );
  }

  /// The stored preferences, or [defaults] when nothing (readable) is stored.
  static GuidePrefs load(KeyValueStore kv,
      {GuidePrefs defaults = const GuidePrefs()}) {
    final raw = kv.getString(key);
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return defaults;
      return GuidePrefs.fromJson(json, defaults: defaults);
    } on Object catch (e) {
      AppLog.info('Stored preferences unreadable, using defaults: $e');
      return defaults;
    }
  }

  Future<void> save(KeyValueStore kv) async {
    try {
      await kv.setString(key, jsonEncode(toJson()));
    } on Object catch (e) {
      AppLog.info('Could not save preferences: $e');
    }
  }
}
