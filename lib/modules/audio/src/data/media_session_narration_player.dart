import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jelajah_taman/core/core.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/narration_player.dart';

/// [NarrationPlayer] on just_audio, published as an Android media session through
/// audio_service (F04 AC1, TC-06): lock-screen controls, the media notification, earphone and
/// Bluetooth buttons.
///
/// - Buttons outside the app become [commands]; the guide decides and calls back
///   [play]/[pause]/[seek]. The handler never plays on its own.
/// - Interruptions (call, another app, earphones unplugged) are handled here through
///   audio_session instead of just_audio's built-in handling, so they also go through the
///   guide ([InterruptionPolicy]).
/// - `androidStopForegroundOnPause: false`: the media service stays in the foreground while
///   paused, because Android 12+ may refuse to start it again from the lock screen. It goes
///   idle (notification removed) only on [stop] (session end). A narration that played to
///   the end shows as paused, so the next one doesn't need a new service start either.
/// - If the media session can't start (no AudioServiceActivity, plugin error) the player
///   still works, just without lock-screen controls.
class MediaSessionNarrationPlayer implements NarrationPlayer {
  MediaSessionNarrationPlayer() {
    _subs
      ..add(_player.processingStateStream.listen((s) {
        if (s == ProcessingState.completed) _completed.add(null);
      }))
      ..add(_player.playbackEventStream.listen((_) => _broadcast()))
      ..add(_player.playingStream.listen((_) => _broadcast()));
  }

  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final _completed = StreamController<void>.broadcast();
  final _commands = StreamController<MediaCommand>.broadcast();
  final _policy = InterruptionPolicy();
  final List<StreamSubscription<Object?>> _subs = [];
  late final _JtAudioHandler _handler = _JtAudioHandler(this);
  Future<void>? _ready;
  String? _loaded;
  bool _idle = true;

  /// Starts the media session (once). Called by the binding at app start, so earphone
  /// buttons reach the app; [open] waits for it.
  Future<void> start() => _ready ??= _init();

  Future<void> _init() async {
    try {
      await AudioService.init(
        builder: () => _handler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'narasi',
          androidNotificationChannelName: 'Narasi',
          androidNotificationChannelDescription:
              'Kontrol cerita yang sedang diputar',
          androidNotificationIcon: 'drawable/ic_stat_jelajah',
          androidStopForegroundOnPause: false,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
    } on Object catch (e) {
      AppLog.info('Media session unavailable: $e (narration plays without it)');
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _subs
        ..add(session.interruptionEventStream
            .listen((e) => _interrupted(switch ((e.begin, e.type)) {
                  (true, AudioInterruptionType.pause) =>
                    AudioInterruption.transientBegin,
                  (true, AudioInterruptionType.duck) =>
                    AudioInterruption.duckBegin,
                  (true, AudioInterruptionType.unknown) =>
                    AudioInterruption.permanentBegin,
                  (false, AudioInterruptionType.pause) =>
                    AudioInterruption.transientEnd,
                  (false, _) => AudioInterruption.otherEnd,
                })))
        ..add(session.becomingNoisyEventStream
            .listen((_) => _interrupted(AudioInterruption.becomingNoisy)));
    } on Object catch (e) {
      AppLog.info('Audio session unavailable: $e');
    }
  }

  void _interrupted(AudioInterruption e) {
    final c = _policy.on(e, playing: _player.playing);
    if (c != null) _commands.add(c);
  }

  /// A button outside the app (lock screen, notification, earphone).
  void _remote(MediaCommand c) {
    if (c == MediaCommand.play || c == MediaCommand.pause) _policy.userActed();
    _commands.add(c);
  }

  /// Mirrors the player into the media session. Completed shows as paused at the end (see
  /// class doc); idle only after [stop].
  void _broadcast() {
    final playing =
        _player.playing && _player.processingState != ProcessingState.completed;
    _handler.playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _idle
          ? AudioProcessingState.idle
          : switch (_player.processingState) {
              ProcessingState.loading => AudioProcessingState.loading,
              ProcessingState.buffering => AudioProcessingState.buffering,
              _ => AudioProcessingState.ready,
            },
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  @override
  Future<Duration?> open(String assetPath, {NarrationInfo? info}) async {
    await start();
    if (_loaded == assetPath) return _player.duration;
    _loaded = assetPath;
    _idle = false;
    final d = await _player.setAsset(assetPath);
    if (info != null) {
      _handler.mediaItem.add(MediaItem(
        id: info.id,
        title: info.title,
        album: info.subtitle,
        artist: 'Jelajah Taman',
        duration: d,
      ));
    }
    _broadcast();
    return d;
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // just_audio's play() completes when playback stops, so don't await it.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    _idle = true;
    _loaded = null;
    await _player.stop();
    _broadcast(); // idle → audio_service stops the service and removes the notification
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Stream<Duration> get position => _player.createPositionStream(
        minPeriod: const Duration(milliseconds: 200),
        maxPeriod: const Duration(milliseconds: 200),
      );

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<MediaCommand> get commands => _commands.stream;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _completed.close();
    await _commands.close();
    await _player.dispose();
  }
}

/// The media session's side: every button is forwarded to the guide as a [MediaCommand].
/// `click()` (earphone) is BaseAudioHandler's: play when paused, pause when playing.
class _JtAudioHandler extends BaseAudioHandler {
  _JtAudioHandler(this._owner);

  final MediaSessionNarrationPlayer _owner;

  @override
  Future<void> play() async => _owner._remote(MediaCommand.play);

  @override
  Future<void> pause() async => _owner._remote(MediaCommand.pause);

  @override
  Future<void> stop() async => _owner._remote(MediaCommand.stop);

  @override
  Future<void> rewind() async => _owner._remote(MediaCommand.rewind);

  @override
  Future<void> fastForward() async => _owner._remote(MediaCommand.fastForward);
}
