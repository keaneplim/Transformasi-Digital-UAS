import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:jelajah_taman/core/core.dart';

import '../domain/audio_contracts.dart';
import '../domain/voice_arbiter.dart';

/// [Speaker] on flutter_tts with the Indonesian voice (F04, risk R3).
///
/// Completion comes from the plugin's complete / cancel / error callbacks, not from
/// `awaitSpeakCompletion`: on Android that future never completes for an utterance cut off
/// by `stop()` (4.2.5, FlutterTtsPlugin.stop), which would hang the arbiter's queue after
/// every interruption. A timeout per line is the last safety net.
class FlutterTtsSpeaker implements Speaker {
  FlutterTtsSpeaker() {
    _tts
      ..setCompletionHandler(_finish)
      ..setCancelHandler(_onCancel)
      ..setErrorHandler((msg) {
        AppLog.info('TTS error: $msg');
        _finish();
      });
  }

  static const _language = 'id-ID';

  final FlutterTts _tts = FlutterTts();
  Future<void>? _setup;
  Completer<void>? _pending;

  /// Cancel callbacks still to come for lines that [stop] already finished.
  int _expectedCancels = 0;

  Future<void> _init() => _setup ??= () async {
        await _tts.awaitSpeakCompletion(false);
        await _tts.setLanguage(_language);
      }();

  void _finish() {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete();
  }

  void _onCancel() {
    if (_expectedCancels > 0) {
      _expectedCancels--; // the cancel of a line stop() already finished: not the current one
      return;
    }
    _finish();
  }

  @override
  Future<void> speak(String text) async {
    await _init();
    _finish();
    final done = Completer<void>();
    _pending = done;
    final started = await _tts.speak(text);
    if (started != 1) {
      if (identical(_pending, done)) _finish();
      throw StateError('TTS did not start (result $started)');
    }
    // Spoken Indonesian runs ~12 characters a second; generous so slow voices aren't cut.
    final limit = Duration(seconds: 5 + text.length ~/ 6);
    await done.future.timeout(limit, onTimeout: () {
      AppLog.info('TTS line timed out after ${limit.inSeconds} s');
      if (identical(_pending, done)) _finish();
    });
  }

  @override
  Future<void> stop() async {
    if (_pending != null) _expectedCancels++;
    _finish();
    await _tts.stop();
  }

  @override
  Future<VoiceSupport> support() async {
    await _init();
    final available = await _tts.isLanguageAvailable(_language) == true;
    if (!available) return VoiceSupport.missing;
    // Only Android says whether the voice works offline.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return VoiceSupport.ready;
    }
    return await _tts.isLanguageInstalled(_language) == true
        ? VoiceSupport.ready
        : VoiceSupport.notInstalled;
  }
}
