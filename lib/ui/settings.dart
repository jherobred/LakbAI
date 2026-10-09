import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../cases/cases.dart';
import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../theme.dart';
import 'lock.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Settings', 'Settings'))),
      body: ListenableBuilder(
        listenable: AiService.instance,
        builder: (context, _) {
          final ai = AiService.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              SectionLabel(tr(context, 'Look and feel', 'Itsura')),
              KCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(context, 'Theme', 'Tema'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(tr(context, 'Auto', 'Auto'))),
                      ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(tr(context, 'Light', 'Light'))),
                      ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(tr(context, 'Dark', 'Dark'))),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => s.themeMode = v.first,
                  ),
                  const SizedBox(height: 16),
                  Text(tr(context, 'Language', 'Wika'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fil', label: Text('Filipino')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {s.lang},
                    onSelectionChanged: (v) => s.lang = v.first,
                  ),
                  const SizedBox(height: 16),
                  Text(tr(context, 'Animations', 'Animation'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    tr(context, 'Auto uses Lite on low-memory phones to keep things smooth.', 'Ang Auto ay gumagamit ng Lite sa phone na mababa ang memory para manatiling mabilis.'),
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MotionMode>(
                    segments: [
                      ButtonSegment(value: MotionMode.auto, label: Text(tr(context, 'Auto', 'Auto'))),
                      ButtonSegment(value: MotionMode.lite, label: Text(tr(context, 'Lite', 'Lite'))),
                      ButtonSegment(value: MotionMode.full, label: Text(tr(context, 'Full', 'Full'))),
                    ],
                    selected: {s.motionMode},
                    onSelectionChanged: (v) => s.motionMode = v.first,
                  ),
                ]),
              ),
              SectionLabel(tr(context, 'On-device AI', 'AI sa phone')),
              KCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ai.active?.name ?? (s.installedModelId == 'imported' ? tr(context, 'Imported model', 'Na-import na model') : tr(context, 'No model installed', 'Walang naka-install na model')),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${s.device.model} · ${s.device.ramLabel} RAM · ${s.device.tier.name}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    const AiStatusPill(),
                  ]),
                  const SizedBox(height: 12),
                  for (final m in kModels)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${m.id == kBundledModelId && ai.modelBundled ? tr(context, 'Built in', 'Kasama na') : m.sizeLabel} · ${s.isFil ? m.blurbFil : m.blurbEn}'),
                      trailing: s.installedModelId == m.id
                          ? Icon(Icons.check_circle_rounded, color: t.success)
                          : (ai.status == AiStatus.downloading && ai.active?.id == m.id)
                              ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(value: ai.progress / 100, strokeWidth: 3))
                              : IconButton(icon: const Icon(Icons.download_rounded), onPressed: ai.status == AiStatus.downloading ? null : () => ai.install(m)),
                    ),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () async {
                        final r = await FilePicker.pickFiles();
                        final p = r.isEmpty ? null : r.first.path;
                        if (p != null) await ai.importFile(p);
                      },
                      icon: const Icon(Icons.file_open_rounded),
                      label: Text(tr(context, 'Import file', 'Mag-import')),
                    ),
                    const Spacer(),
                    if (s.installedModelId != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: t.danger),
                        onPressed: ai.deleteModel,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(tr(context, 'Remove', 'Alisin')),
                      ),
                  ]),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mic_rounded),
                    title: Text(tr(context, 'Voice model', 'Voice model'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(ai.voiceReady ? (s.installedVoiceId ?? '') : tr(context, 'Not installed', 'Hindi pa naka-install')),
                    trailing: ai.voiceReady
                        ? Icon(Icons.check_circle_rounded, color: t.success)
                        : ai.voiceDownloading
                            ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(value: ai.voiceProgress / 100, strokeWidth: 3))
                            : IconButton(icon: const Icon(Icons.download_rounded), onPressed: () => ai.installVoice(recommendedVoice(s.device.tier))),
                  ),
                ]),
              ),
              SectionLabel(tr(context, 'Privacy and safety', 'Privacy at kaligtasan')),
              KCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(children: [
                  SwitchListTile(
                    title: Text(tr(context, 'PIN lock', 'PIN lock'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(tr(context, 'Locks the app whenever you leave it', 'Naka-lock tuwing aalis ka sa app')),
                    value: s.hasPin,
                    onChanged: (v) async {
                      if (v) {
                        await showPinSetup(context);
                      } else {
                        s.clearPin();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(tr(context, 'Quick exit', 'Mabilis na labas'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(tr(context, 'The red door icon on the home screen closes Kontrata instantly.', 'Ang pulang icon sa home screen ay agad na nagsasara ng Kontrata.')),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_rounded, color: t.danger),
                    title: Text(tr(context, 'Delete everything', 'Burahin lahat'), style: TextStyle(fontWeight: FontWeight.w700, color: t.danger)),
                    subtitle: Text(tr(context, 'Removes all cases, photos, reports and settings', 'Buburahin ang lahat ng kaso, litrato, report at settings')),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(tr(c, 'Delete everything?', 'Burahin lahat?')),
                          content: Text(tr(c, 'This cannot be undone.', 'Hindi na ito maibabalik.')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Cancel', 'Kanselahin'))),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Delete', 'Burahin'))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await CaseRepository.instance.wipeAll();
                        await AiService.instance.deleteModel();
                        await s.wipe();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                  ),
                ]),
              ),
              SectionLabel(tr(context, 'About', 'Tungkol')),
              KCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const KLogo(size: 36),
                    const SizedBox(width: 10),
                    Text('Kontrata', style: Theme.of(context).textTheme.titleLarge),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    tr(context,
                        'Runs fully on this phone: language model (LiteRT-LM via flutter_edge_ai), speech-to-text (Whisper), and text recognition (Google ML Kit). Internet is used only to download models once.',
                        'Tumatakbo nang buo sa phone: language model (LiteRT-LM sa flutter_edge_ai), speech-to-text (Whisper), at text recognition (Google ML Kit). Ginagamit lang ang internet para i-download ang model nang isang beses.'),
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text('${tr(context, 'Legal guide version', 'Bersyon ng legal guide')}: ${KnowledgeBase.instance.version}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(KnowledgeBase.instance.disclaimer(s.isFil), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
