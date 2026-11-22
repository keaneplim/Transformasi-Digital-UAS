import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';
import 'package:jelajah_taman/modules/audio/audio.dart';
import 'package:jelajah_taman/modules/location/location.dart';

import '../data/device_permissions.dart';
import '../state/guide_controller.dart';
import '../state/places.dart';

/// UI15 Settings. Visitor preferences first (kept on the phone, #32), then the phone
/// permissions the guide relies on (allow again or open the phone's settings, PB07/T27); the
/// "Mode demo" panel (preview tools to move around the park without GPS) sits collapsed at
/// the bottom.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final voice = ref.watch(ttsServiceProvider);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: JT.cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, pad.top + 8, JT.gutter, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(JT.gutter, 14, JT.gutter, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: HighlightHeadline(
                      before: 'Atur sesuai ',
                      highlight: 'gaya Anda',
                      style: JTText.display,
                    ),
                  ),
                  const Pako(pose: PakoPose.thinking, size: 70, shadow: false),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: JT.gutter),
            sliver: SliverList.list(
              children: [
                _Group(
                  title: 'Pemandu',
                  children: [
                    _SwitchRow(
                      icon: Icons.auto_mode_rounded,
                      color: JT.forest,
                      title: 'Putar otomatis saat tiba',
                      subtitle:
                          'Cerita langsung diputar tanpa menyentuh layar.',
                      value: demo.autoPlay,
                      onChanged: (v) => demo.update(() => demo.autoPlay = v),
                    ),
                    _SwitchRow(
                      icon: Icons.record_voice_over_rounded,
                      color: JT.sky,
                      title: 'Arahan suara',
                      subtitle:
                          'Petunjuk belok dan kedatangan dibacakan saat navigasi.',
                      value: demo.voiceGuidance,
                      onChanged: (v) =>
                          demo.update(() => demo.voiceGuidance = v),
                    ),
                    _SwitchRow(
                      icon: Icons.vibration_rounded,
                      color: JT.category('rekreasi'),
                      title: 'Getar',
                      subtitle:
                          'Saat mendekati dan tiba di tempat menarik, juga untuk pengingat.',
                      value: demo.vibration,
                      onChanged: (v) => demo.update(() => demo.vibration = v),
                    ),
                  ],
                ),
                if (voice != null) _VoiceHint(voice),
                const _PermissionsGroup(),
                _Group(
                  title: 'Kesehatan',
                  children: [
                    _ChoiceRow<int>(
                      icon: Icons.water_drop_rounded,
                      color: JT.sky,
                      title: 'Pengingat minum',
                      options: const [
                        (0, 'Mati'),
                        (30, '30 mnt'),
                        (45, '45 mnt'),
                        (60, '60 mnt')
                      ],
                      value: demo.hydrationMin,
                      onChanged: (v) =>
                          demo.update(() => demo.hydrationMin = v),
                    ),
                    _WeightRow(
                      value: demo.weightKg,
                      onChanged: (v) => demo.update(() => demo.weightKg = v),
                    ),
                  ],
                ),
                _Group(
                  title: 'Tampilan',
                  children: [
                    _ChoiceRow<double>(
                      icon: Icons.text_fields_rounded,
                      color: JT.category('sejarah'),
                      title: 'Ukuran teks',
                      options: const [
                        (1.0, 'Normal'),
                        (1.15, 'Besar'),
                        (1.3, 'Lebih besar')
                      ],
                      value: demo.textScale,
                      onChanged: (v) => demo.update(() => demo.textScale = v),
                    ),
                  ],
                ),
                _Group(
                  title: 'Privasi',
                  children: [
                    const _InfoRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Tanpa akun',
                      subtitle:
                          'Lokasi dan riwayat hanya disimpan di ponsel ini.',
                    ),
                    _ActionRow(
                      icon: Icons.restart_alt_rounded,
                      color: JT.terracotta,
                      title: 'Hapus riwayat jelajah',
                      onTap: () async {
                        final ok = await _confirm(
                            context,
                            'Hapus riwayat jelajah?',
                            'Tempat yang dikunjungi dan langkah akan dihapus.');
                        if (ok) demo.resetAll();
                      },
                    ),
                    _ActionRow(
                      icon: Icons.replay_rounded,
                      color: JT.muted,
                      title: 'Ulangi perkenalan',
                      onTap: () {
                        demo.update(() => demo.onboarded = false);
                        context.go('/welcome');
                      },
                    ),
                  ],
                ),
                _Group(
                  title: 'Tentang',
                  children: [
                    _InfoRow(
                      icon: Icons.offline_pin_rounded,
                      title: 'Data offline',
                      subtitle:
                          'Tersedia · versi ${demo.content.contentVersion}',
                    ),
                    _ActionRow(
                      icon: Icons.info_outline_rounded,
                      color: JT.muted,
                      title: 'Tentang & atribusi',
                      onTap: () => context.push('/about'),
                    ),
                    const _VersionRow(),
                  ],
                ),
                const _DemoPanel(),
                if (demo.debugMenuUnlocked) ...[
                  const SizedBox(height: 14),
                  const _DebugPanel(),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const DoodleIcon(Doodle.pine, size: 28, color: JT.doodle),
                      const SizedBox(height: 6),
                      Text('Jelajah Taman · Tahura Ir. H. Djuanda',
                          style: JTText.caption.copyWith(color: JT.faint)),
                    ],
                  ),
                ),
                SizedBox(height: 28 + pad.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body,
        {String confirm = 'Hapus', Color color = JT.terracotta}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: JT.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JT.rCard)),
        title: Text(title, style: JTText.h3),
        content: Text(body, style: JTText.body.copyWith(color: JT.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

/// F04 / risk R3: without an offline Indonesian voice the guide can't speak in the park.
/// Shown only then; nothing when the voice is ready.
class _VoiceHint extends StatelessWidget {
  const _VoiceHint(this.voice);

  final TtsService voice;

  @override
  Widget build(BuildContext context) => FutureBuilder<VoiceSupport>(
        future: voice.support,
        builder: (context, snap) {
          final s = snap.data;
          if (s == null || s == VoiceSupport.ready) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: JT.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suara bahasa Indonesia belum terpasang di ponsel ini, jadi '
                    'panduan suara tidak terdengar. Pasang lewat Pengaturan '
                    'ponsel → Teks ke ucapan.',
                    style: JTText.caption,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

/// "Izin ponsel": what the guide may use, why it matters, and a way to allow it again —
/// the system dialog while Android still offers it, else the app's page in the phone's
/// settings. Re-read when the visitor comes back to the app.
class _PermissionsGroup extends ConsumerStatefulWidget {
  const _PermissionsGroup();

  @override
  ConsumerState<_PermissionsGroup> createState() => _PermissionsGroupState();
}

class _PermissionsGroupState extends ConsumerState<_PermissionsGroup> {
  PermissionState? _notify;
  PermissionState? _activity;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  DevicePermissions? get _perms => ref.read(devicePermissionsProvider);

  Future<void> _refresh() async {
    final perms = _perms;
    final guide = ref.read(guideProvider);
    unawaited(guide.refreshAccess());
    if (perms == null) return;
    try {
      final n = await perms.notifications();
      final a = await perms.activity();
      if (mounted) {
        setState(() {
          _notify = n;
          _activity = a;
        });
      }
    } on Object {
      // Plugin missing (preview): the rows just stay hidden.
    }
  }

  Future<void> _allow(
      Future<PermissionState> Function() ask, PermissionState? now) async {
    final perms = _perms;
    if (perms == null) return;
    unawaited(HapticFeedback.selectionClick());
    if (now == PermissionState.blocked) {
      await perms.openAppSettings(); // _refresh runs on the way back
      return;
    }
    await ask();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(guideProvider);
    final perms = ref.watch(devicePermissionsProvider);
    final location = guide.locationSupported && !guide.isDemo
        ? switch (guide.access) {
            null => null,
            LocationAccess.granted => PermissionState.granted,
            LocationAccess.denied => PermissionState.denied,
            LocationAccess.deniedForever ||
            LocationAccess.serviceOff =>
              PermissionState.blocked,
          }
        : null;
    final rows = <Widget>[
      if (location != null)
        _PermissionRow(
          icon: Icons.my_location_rounded,
          color: JT.sky,
          title: 'Lokasi',
          state: location,
          on: 'Cerita diputar saat Anda tiba di setiap tempat.',
          off: guide.access == LocationAccess.serviceOff
              ? 'GPS ponsel mati. Nyalakan agar pemandu tahu posisi Anda.'
              : 'Tanpa lokasi, pindai kode QR atau pilih tempat secara manual.',
          onAllow: () async {
            unawaited(HapticFeedback.selectionClick());
            if (location == PermissionState.blocked) {
              await (guide.access == LocationAccess.serviceOff
                  ? guide.openLocationSettings()
                  : perms?.openAppSettings());
            } else {
              await guide.requestLocation();
            }
          },
        ),
      if (perms != null && _notify != null)
        _PermissionRow(
          icon: Icons.notifications_active_rounded,
          color: JT.category('rekreasi'),
          title: 'Notifikasi',
          state: _notify!,
          on: 'Pemberitahuan tiba dan pengingat muncul di layar kunci.',
          off: 'Pemberitahuan di layar kunci tidak muncul. Kartu di aplikasi '
              'dan suara pemandu tetap ada.',
          onAllow: () => _allow(perms.requestNotifications, _notify),
        ),
      if (perms != null && _activity != null && !guide.isDemo)
        _PermissionRow(
          icon: Icons.directions_walk_rounded,
          color: JT.category('alam'),
          title: 'Aktivitas fisik',
          state: _activity!,
          on: 'Langkah Anda dihitung selama penjelajahan.',
          off: 'Langkah tidak dihitung. Jarak dan durasi tetap tercatat.',
          onAllow: () async {
            if (_activity == PermissionState.blocked) {
              await _allow(perms.requestActivity, _activity);
            } else {
              unawaited(HapticFeedback.selectionClick());
              await guide.requestActivity();
              await _refresh();
            }
          },
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Group(title: 'Izin ponsel', children: rows);
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.state,
    required this.on,
    required this.off,
    required this.onAllow,
  });

  final IconData icon;
  final Color color;
  final String title;
  final PermissionState state;
  final String on;
  final String off;
  final VoidCallback onAllow;

  static const _warn = Color(0xFFA63A22);

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionState.granted;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Leading(icon, granted ? color : JT.faint),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: AnimatedSwitcher(
                    duration: JTMotion.base,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(granted),
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: granted ? JT.leaf : JT.terracotta,
                        shape: BoxShape.circle,
                        border: Border.all(color: JT.surface, width: 2),
                      ),
                      child: Icon(
                          granted
                              ? Icons.check_rounded
                              : Icons.priority_high_rounded,
                          size: 10,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: JTText.title)),
                      const SizedBox(width: 8),
                      Text(granted ? 'Aktif' : 'Nonaktif',
                          style: JTText.caption.copyWith(
                              color: granted ? JT.forestBright : _warn,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: JTMotion.base,
                    child: Text(granted ? on : off,
                        key: ValueKey(granted), style: JTText.caption),
                  ),
                  if (!granted) ...[
                    const SizedBox(height: 10),
                    SoftButton(
                      label: state == PermissionState.blocked
                          ? 'Buka pengaturan ponsel'
                          : 'Izinkan',
                      icon: state == PermissionState.blocked
                          ? Icons.open_in_new_rounded
                          : Icons.check_circle_outline_rounded,
                      height: 40,
                      expand: false,
                      color: Color.lerp(color, JT.cream, 0.82)!,
                      foreground: Color.lerp(color, JT.ink, 0.35)!,
                      onTap: onAllow,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(), style: JTText.overline),
            ),
            JTCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      const Divider(
                          height: 1, indent: 66, endIndent: 16, color: JT.line),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _Leading extends StatelessWidget {
  const _Leading(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Color.lerp(color, JT.cream, 0.82),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 20),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                _Leading(icon, color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: JTText.title),
                      const SizedBox(height: 2),
                      Text(subtitle, style: JTText.caption),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Leading(icon, color),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: JTText.title)),
              ],
            ),
            const SizedBox(height: 12),
            _Segmented<T>(options: options, value: value, onChanged: onChanged),
          ],
        ),
      );
}

/// Segmented control with a sliding thumb.
class _Segmented<T> extends StatelessWidget {
  const _Segmented(
      {required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index =
        options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: JT.creamDeep, borderRadius: BorderRadius.circular(23)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: JTMotion.base,
                curve: JTMotion.emphasized,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: JT.forest,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(options[i].$1);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: JTMotion.base,
                              style: JTText.label.copyWith(
                                color: i == index ? Colors.white : JT.muted,
                              ),
                              child: Text(options[i].$2, maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Leading(Icons.monitor_weight_outlined, JT.category('alam')),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Berat badan', style: JTText.title),
                      Text('Opsional, agar perkiraan energi lebih tepat.',
                          style: JTText.caption),
                    ],
                  ),
                ),
                Text(value == null ? '—' : '${value!.round()} kg',
                    style: JTText.number(17)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: value ?? 60,
                    min: 30,
                    max: 130,
                    divisions: 100,
                    activeColor: value == null ? JT.faint : JT.forest,
                    label: '${(value ?? 60).round()} kg',
                    onChanged: onChanged,
                  ),
                ),
                if (value != null)
                  TextButton(
                      onPressed: () => onChanged(null),
                      child: const Text('Kosongkan')),
              ],
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            _Leading(icon, JT.forest),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: JTText.title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: JTText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              _Leading(icon, color),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      style: JTText.title.copyWith(
                          color: color == JT.muted ? JT.ink : color))),
              const Icon(Icons.chevron_right_rounded, color: JT.faint),
            ],
          ),
        ),
      );
}

/// "Mode demo": the switch between live GPS and the simulated position, plus the preview
/// tools (move without GPS, speed up the walk, fake the clock) that only work in demo mode.
class _DemoPanel extends ConsumerStatefulWidget {
  const _DemoPanel();

  @override
  ConsumerState<_DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends ConsumerState<_DemoPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(guideProvider);
    return Container(
      decoration: BoxDecoration(
        color: JT.dusk,
        borderRadius: BorderRadius.circular(JT.rCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.science_rounded, color: JT.sun),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mode demo',
                            style: JTText.title.copyWith(color: Colors.white)),
                        Text(
                            demo.isDemo
                                ? 'Aktif: posisi Anda disimulasikan.'
                                : 'Coba fitur tanpa berada di taman.',
                            style:
                                JTText.caption.copyWith(color: Colors.white60)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: demo.isDemo,
                    activeTrackColor: JT.sun,
                    inactiveTrackColor: Colors.white24,
                    inactiveThumbColor: Colors.white70,
                    trackOutlineColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: (on) async {
                      final ok = await _confirm(
                        context,
                        on ? 'Nyalakan Mode demo?' : 'Kembali ke lokasi asli?',
                        on
                            ? 'Posisi Anda akan disimulasikan dari gerbang. Jelajah yang sedang berjalan dimulai ulang.'
                            : 'Pemandu akan memakai GPS ponsel Anda. Jelajah demo dimulai ulang.',
                        confirm: on ? 'Nyalakan' : 'Pakai GPS',
                        color: JT.forest,
                      );
                      if (ok) demo.setMode(on ? AppMode.demo : AppMode.real);
                    },
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: JTMotion.base,
                    child: const Icon(Icons.expand_more_rounded,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: JTMotion.slow,
            curve: JTMotion.emphasized,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!demo.isDemo)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Nyalakan Mode demo untuk berpindah tempat, mempercepat jalan, dan mengatur jam.',
                              style: JTText.caption
                                  .copyWith(color: Colors.white70),
                            ),
                          ),
                        if (demo.isDemo) ...[
                          _label('PINDAH KE'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in demo.pois)
                                _DarkChip(
                                  label: p.name,
                                  onTap: () {
                                    if (!demo.sessionActive) {
                                      demo.startSession();
                                    }
                                    demo.teleportTo(p);
                                    if (!p.isGate) demo.triggerNow(p);
                                  },
                                ),
                            ],
                          ),
                          _label('KECEPATAN JALAN SIMULASI'),
                          _Segmented<double>(
                            options: const [
                              (10.0, '10×'),
                              (25.0, '25×'),
                              (60.0, '60×')
                            ],
                            value: demo.walkSpeedFactor,
                            onChanged: (v) =>
                                demo.update(() => demo.walkSpeedFactor = v),
                          ),
                          _label('JAM (${clockLabel(demo.now())})'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DarkChip(
                                  label: '09.00',
                                  onTap: () => demo.setDemoTime(9, 0)),
                              _DarkChip(
                                  label: '13.00',
                                  onTap: () => demo.setDemoTime(13, 0)),
                              _DarkChip(
                                  label: '15.30',
                                  onTap: () => demo.setDemoTime(15, 30)),
                              _DarkChip(
                                  label: 'Sekarang', onTap: demo.resetDemoTime),
                            ],
                          ),
                        ],
                        _label('PENGINGAT'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DarkChip(
                              label: 'Jam tutup',
                              icon: Icons.schedule_rounded,
                              onTap: () {
                                context.pop();
                                demo.showReminder(GuideReminder.closing);
                              },
                            ),
                            _DarkChip(
                              label: 'Panggilan terakhir',
                              icon: Icons.warning_amber_rounded,
                              onTap: () {
                                context.pop();
                                demo.showReminder(GuideReminder.finalCall);
                              },
                            ),
                            _DarkChip(
                              label: 'Minum',
                              icon: Icons.water_drop_rounded,
                              onTap: () {
                                context.pop();
                                demo.showReminder(GuideReminder.hydration);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SoftButton(
                          label: 'Reset semua',
                          icon: Icons.restart_alt_rounded,
                          color: Colors.white.withValues(alpha: 0.1),
                          foreground: Colors.white,
                          onTap: demo.resetAll,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(s, style: JTText.overline.copyWith(color: Colors.white54)),
      );
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: JT.sun),
                const SizedBox(width: 6),
              ],
              Text(label, style: JTText.label.copyWith(color: Colors.white)),
            ],
          ),
        ),
      );
}

/// Version row in "Tentang": 7 taps unlock the hidden debug menu (UC-SH-5 / T31).
class _VersionRow extends ConsumerStatefulWidget {
  const _VersionRow();

  @override
  ConsumerState<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends ConsumerState<_VersionRow> {
  static const _needed = 7;
  int _taps = 0;

  void _onTap() {
    final demo = ref.read(guideProvider);
    if (demo.debugMenuUnlocked) return;
    _taps++;
    final left = _needed - _taps;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (left <= 0) {
      _taps = 0;
      demo.unlockDebugMenu();
      unawaited(HapticFeedback.mediumImpact());
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Menu debug aktif',
              style: JTText.body.copyWith(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: JT.dusk,
        ));
    } else if (_taps >= 4) {
      unawaited(HapticFeedback.selectionClick());
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('$left ketukan lagi untuk membuka menu debug',
              style: JTText.body.copyWith(color: Colors.white)),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
          backgroundColor: JT.ink,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(guideProvider).debugMenuUnlocked;
    return InkWell(
      onTap: _onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const _Leading(Icons.verified_outlined, JT.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versi aplikasi', style: JTText.title),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? '${GuideController.appVersion} · Menu debug aktif'
                        : GuideController.appVersion,
                    style: JTText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hidden debug menu unlocked by 7 taps on the version row (UC-SH-5 / §6.5 / T31).
class _DebugPanel extends ConsumerWidget {
  const _DebugPanel();

  Future<void> _pickClock(BuildContext context, GuideController demo) async {
    final cur = demo.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
    );
    if (picked != null) {
      demo.setClockTime(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(guideProvider);
    final moving = demo.trackingMode == TrackingMode.moving;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JT.dusk,
        borderRadius: BorderRadius.circular(JT.rCard),
        border: Border.all(color: JT.sun.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: JT.sun),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Menu debug',
                        style: JTText.title.copyWith(color: Colors.white)),
                    Text('Diagnostik GPS, geofence, dan jam uji',
                        style: JTText.caption.copyWith(color: Colors.white60)),
                  ],
                ),
              ),
              TextButton(
                onPressed: demo.lockDebugMenu,
                style: TextButton.styleFrom(foregroundColor: JT.sun),
                child: const Text('Tutup'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS ${demo.activeGpsInterval.inSeconds} dtk · '
                  '${moving ? "Bergerak" : "Diam (hemat baterai)"}'
                  '${demo.accuracyM != null ? " · ±${demo.accuracyM!.round()} m" : ""}',
                  style: JTText.caption.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tutup ${clockLabel(demo.closingTime)} · '
                  'Pengingat ${clockLabel(demo.closingReminderAt)} · '
                  'Panggilan akhir ${clockLabel(demo.finalCallAt)}',
                  style: JTText.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DebugSwitch(
            title: 'Overlay debug di Peta',
            subtitle: 'Tampilkan interval GPS, jarak & state tiap POI.',
            value: demo.debugOverlay,
            onChanged: demo.setDebugOverlay,
          ),
          _DebugSwitch(
            title: 'Simulasi GPS lemah (UI12)',
            subtitle: 'Tampilkan banner QR & pilih manual di Peta.',
            value: demo.debugWeakGps,
            onChanged: demo.setDebugWeakGps,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text('JAM SIMULASI (${clockLabel(demo.now())})',
                style: JTText.overline.copyWith(color: Colors.white54)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkChip(
                  label: '−15 mnt',
                  onTap: () => demo.shiftClock(const Duration(minutes: -15))),
              _DarkChip(
                  label: '−1 mnt',
                  onTap: () => demo.shiftClock(const Duration(minutes: -1))),
              _DarkChip(
                  label: '+1 mnt',
                  onTap: () => demo.shiftClock(const Duration(minutes: 1))),
              _DarkChip(
                  label: '+15 mnt',
                  onTap: () => demo.shiftClock(const Duration(minutes: 15))),
              _DarkChip(
                  label: 'Pilih jam…',
                  icon: Icons.access_time_rounded,
                  onTap: () => _pickClock(context, demo)),
              _DarkChip(label: 'Sekarang', onTap: demo.resetDemoTime),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text('AKSI UJI',
                style: JTText.overline.copyWith(color: Colors.white54)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkChip(
                label: 'Panggilan terakhir',
                icon: Icons.warning_amber_rounded,
                onTap: () {
                  context.pop();
                  demo.showReminder(GuideReminder.finalCall);
                },
              ),
              _DarkChip(
                label: 'Salin log sesi',
                icon: Icons.copy_rounded,
                onTap: () {
                  unawaited(Clipboard.setData(
                      ClipboardData(text: demo.debugLogSummary())));
                  ScaffoldMessenger.maybeOf(context)
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text('Ringkasan log sesi disalin',
                          style: JTText.body.copyWith(color: Colors.white)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: JT.ink,
                    ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugSwitch extends StatelessWidget {
  const _DebugSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: JTText.label.copyWith(color: Colors.white)),
                  Text(subtitle,
                      style: JTText.caption.copyWith(color: Colors.white60)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: JT.sun,
              inactiveTrackColor: Colors.white24,
              inactiveThumbColor: Colors.white70,
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              onChanged: onChanged,
            ),
          ],
        ),
      );
}
