import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jelajah_taman/core/ui/ui.dart';

import '../demo/demo_controller.dart';
import '../demo/places.dart';

/// UI15 Settings. Visitor preferences first; the "Mode demo" panel (preview tools to
/// move around the park without GPS) sits collapsed at the bottom.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
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
                      subtitle: 'Petunjuk belok dibacakan saat navigasi.',
                      value: demo.voiceGuidance,
                      onChanged: (v) =>
                          demo.update(() => demo.voiceGuidance = v),
                    ),
                    _SwitchRow(
                      icon: Icons.vibration_rounded,
                      color: JT.category('rekreasi'),
                      title: 'Getar',
                      subtitle:
                          'Getaran singkat saat mendekati tempat menarik.',
                      value: demo.vibration,
                      onChanged: (v) => demo.update(() => demo.vibration = v),
                    ),
                  ],
                ),
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
                const _DemoPanel(),
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

Future<bool> _confirm(BuildContext context, String title, String body) async =>
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
            style: TextButton.styleFrom(foregroundColor: JT.terracotta),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
    false;

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

/// Preview tools: move without GPS, speed up the walk, fire reminders, fake the clock.
class _DemoPanel extends ConsumerStatefulWidget {
  const _DemoPanel();

  @override
  ConsumerState<_DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends ConsumerState<_DemoPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoProvider);
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
                        Text('Coba fitur tanpa berada di taman.',
                            style:
                                JTText.caption.copyWith(color: Colors.white60)),
                      ],
                    ),
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
                        _label('PINDAH KE'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in demo.pois)
                              _DarkChip(
                                label: p.name,
                                onTap: () {
                                  if (!demo.sessionActive) demo.startSession();
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
                                demo.showReminder(DemoReminder.closing);
                              },
                            ),
                            _DarkChip(
                              label: 'Minum',
                              icon: Icons.water_drop_rounded,
                              onTap: () {
                                context.pop();
                                demo.showReminder(DemoReminder.hydration);
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
