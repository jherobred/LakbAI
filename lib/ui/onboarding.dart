import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai/ai_service.dart';
import '../core/app_state.dart';
import '../theme.dart';
import 'lock.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  static const _count = 5;

  void _go(int i) {
    HapticFeedback.selectionClick();
    _pc.animateToPage(i, duration: Motion.d(context, 480), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _page == _count - 1;
    return Scaffold(
      body: Stack(children: [
        const _Backdrop(),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(children: [
                const KLogo(size: 30),
                const SizedBox(width: 8),
                Text('Kontrata', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const _LangToggle(),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [_Welcome(), _Privacy(), _HowItWorks(), _Country(), _AiSetup()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(children: [
                _Dots(count: _count, index: _page),
                const Spacer(),
                AnimatedSwitcher(
                  duration: Motion.d(context, 250),
                  child: _page == 0
                      ? const SizedBox(width: 0)
                      : TextButton(key: const ValueKey('back'), onPressed: () => _go(_page - 1), child: Text(tr(context, 'Back', 'Bumalik'))),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () async {
                    if (!last) return _go(_page + 1);
                    await _finish(context);
                  },
                  child: AnimatedSwitcher(
                    duration: Motion.d(context, 250),
                    child: Text(
                      last ? tr(context, 'Start', 'Simulan') : tr(context, 'Next', 'Susunod'),
                      key: ValueKey(last),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
      backgroundColor: cs.surfaceContainerLowest,
    );
  }

  Future<void> _finish(BuildContext context) async {
    final s = AppScope.read(context);
    final wantPin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.lock_rounded),
        title: Text(tr(c, 'Lock Kontrata with a PIN?', 'I-lock ang Kontrata gamit ang PIN?')),
        content: Text(tr(c, 'Recommended if someone else may check your phone. You can change this later in Settings.',
            'Mainam kung may ibang tumitingin sa phone mo. Puwede mo itong baguhin sa Settings.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Not now', 'Hindi muna'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'Set PIN', 'Maglagay ng PIN'))),
        ],
      ),
    );
    if (wantPin == true && context.mounted) {
      await showPinSetup(context);
    }
    s.onboarded = true;
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    final t = KTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget blob(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
        );
    final reduced = Motion.reduced(context);
    Widget a(Widget w, double dx, double dy, int ms) =>
        reduced ? w : w.animate(onPlay: (c) => c.repeat(reverse: true)).move(begin: Offset.zero, end: Offset(dx, dy), duration: ms.ms, curve: Curves.easeInOut);
    return IgnorePointer(
      child: Stack(children: [
        Positioned(top: -120, right: -80, child: a(blob(t.glow, 340), -30, 40, 6000)),
        Positioned(bottom: -140, left: -100, child: a(blob(cs.secondary.withValues(alpha: 0.18), 360), 40, -30, 7000)),
      ]),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
      segments: const [
        ButtonSegment(value: 'fil', label: Text('Filipino')),
        ButtonSegment(value: 'en', label: Text('English')),
      ],
      selected: {s.lang},
      onSelectionChanged: (v) => s.lang = v.first,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: Motion.d(context, 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 6),
          width: i == index ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(color: i == index ? cs.primary : cs.outline, borderRadius: BorderRadius.circular(99)),
        ),
    ]);
  }
}

/// Shared page layout: hero visual, title, body.
class _Page extends StatelessWidget {
  const _Page({required this.visual, required this.title, required this.body, this.extra});
  final Widget visual;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = Motion.d(context, 500);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: visual).animate().fadeIn(duration: d).scaleXY(begin: 0.9, curve: Curves.easeOutBack, duration: d),
        const SizedBox(height: 28),
        Text(title, style: Theme.of(context).textTheme.headlineMedium).animate().fadeIn(delay: 120.ms, duration: d).slideY(begin: 0.2, curve: Curves.easeOutCubic),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant))
            .animate()
            .fadeIn(delay: 220.ms, duration: d)
            .slideY(begin: 0.2, curve: Curves.easeOutCubic),
        if (extra != null) ...[const SizedBox(height: 20), extra!.animate().fadeIn(delay: 320.ms, duration: d)],
      ]),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) {
    return _Page(
      visual: const KLogo(size: 150, animate: true),
      title: tr(context, 'Know if your contract was changed.', 'Alamin kung binago ang kontrata mo.'),
      body: tr(context,
          'Kontrata compares the contract DMW verified with the one you are asked to sign abroad, explains every change, and helps you decide what to do. Safely, at your own pace.',
          'Ikinukumpara ng Kontrata ang kontratang na-verify ng DMW sa kontratang pinapapirma sa iyo sa abroad, ipinapaliwanag ang bawat pagbabago, at tinutulungan kang magpasya. Ligtas, at sa sarili mong bilis.'),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    Widget row(IconData i, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: t.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(i, size: 20, color: t.success),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
          ]),
        );
    return _Page(
      visual: SizedBox(
        width: 170,
        height: 150,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
          ),
          Icon(Icons.phone_android_rounded, size: 82, color: cs.primary),
          Positioned(
            right: 12,
            top: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
              child: const Icon(Icons.airplanemode_active_rounded, color: Colors.white, size: 22),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1400.ms, curve: Curves.easeInOut),
          ),
          const Positioned(bottom: 22, child: Icon(Icons.lock_rounded, size: 28, color: Colors.white)),
        ]),
      ),
      title: tr(context, 'Everything stays on your phone.', 'Nasa phone mo lang ang lahat.'),
      body: tr(context, 'The AI runs on this phone, even in airplane mode. No account, no uploads.',
          'Tumatakbo ang AI sa phone na ito, kahit naka-airplane mode. Walang account, walang ina-upload.'),
      extra: Column(children: [
        row(Icons.wifi_off_rounded, tr(context, 'Works with no internet or load', 'Gumagana kahit walang internet o load')),
        row(Icons.visibility_off_rounded, tr(context, 'Your employer cannot see it online', 'Hindi ito makikita ng employer online')),
        row(Icons.back_hand_rounded, tr(context, 'You decide if and when to share anything', 'Ikaw ang magpapasya kung kailan magbabahagi')),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget step(int n, IconData i, String title, String sub, int delay) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: KCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(gradient: KTokens.of(context).hero, borderRadius: BorderRadius.circular(14)),
                child: Icon(i, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$n. $title', style: Theme.of(context).textTheme.titleMedium),
                  Text(sub, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5)),
                ]),
              ),
            ]),
          ).animate().fadeIn(delay: delay.ms, duration: Motion.d(context, 400)).slideX(begin: 0.15, curve: Curves.easeOutCubic),
        );
    return _Page(
      visual: Icon(Icons.compare_rounded, size: 110, color: cs.primary),
      title: tr(context, 'Three steps.', 'Tatlong hakbang.'),
      body: tr(context, 'You can also just ask questions about your rights, by typing or talking.',
          'Puwede ka ring magtanong tungkol sa karapatan mo, sa pag-type o pagsasalita.'),
      extra: Column(children: [
        step(1, Icons.verified_rounded, tr(context, 'Scan your verified contract', 'I-scan ang na-verify na kontrata'),
            tr(context, 'The copy DMW approved before you left', 'Ang kopyang inaprubahan ng DMW bago ka umalis'), 250),
        step(2, Icons.document_scanner_rounded, tr(context, 'Scan the new contract', 'I-scan ang bagong kontrata'),
            tr(context, 'The one you are asked to sign', 'Ang pinapapirma sa iyo'), 380),
        step(3, Icons.fact_check_rounded, tr(context, 'See what changed', 'Tingnan ang binago'),
            tr(context, 'Plus safe options and a ready report', 'Kasama ang ligtas na hakbang at handang report'), 510),
      ]),
    );
  }
}

class _Country extends StatelessWidget {
  const _Country();
  static const options = {
    'ksa': ('Saudi Arabia', '🇸🇦'),
    'uae': ('UAE', '🇦🇪'),
    'kw': ('Kuwait', '🇰🇼'),
    'qa': ('Qatar', '🇶🇦'),
    'hk': ('Hong Kong', '🇭🇰'),
    'sg': ('Singapore', '🇸🇬'),
    'other': ('Other / not yet', '🌏'),
  };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Page(
      visual: Icon(Icons.travel_explore_rounded, size: 110, color: cs.primary),
      title: tr(context, 'Where are you working?', 'Saan ka nagtatrabaho?'),
      body: tr(context, 'This helps Kontrata check local minimums. You can skip it.',
          'Para ma-check ng Kontrata ang minimum doon. Puwedeng laktawan.'),
      extra: Wrap(spacing: 10, runSpacing: 10, children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text('${e.value.$2}  ${e.value.$1}'),
            selected: s.country == e.key,
            onSelected: (_) => s.country = e.key,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
      ]),
    );
  }
}

class _AiSetup extends StatelessWidget {
  const _AiSetup();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: AiService.instance,
      builder: (context, _) {
        final ai = AiService.instance;
        final rec = recommendedModel(s.device.tier);
        final downloading = ai.status == AiStatus.downloading;
        final ready = ai.status == AiStatus.ready;
        return _Page(
          visual: ProgressRing(
            value: ready ? 1 : (downloading ? ai.progress / 100 : 0),
            size: 150,
            child: AnimatedSwitcher(
              duration: Motion.d(context, 300),
              child: ready
                  ? Icon(Icons.check_rounded, key: const ValueKey('ok'), size: 64, color: KTokens.of(context).success)
                  : downloading
                      ? Text('${ai.progress}%', key: const ValueKey('pct'), style: Theme.of(context).textTheme.headlineMedium)
                      : ai.status == AiStatus.loading
                          ? const SizedBox.square(key: ValueKey('load'), dimension: 48, child: CircularProgressIndicator(strokeWidth: 4))
                          : Icon(Icons.memory_rounded, key: const ValueKey('chip'), size: 58, color: cs.primary),
            ),
          ),
          title: ready
              ? tr(context, 'Offline AI is ready.', 'Handa na ang offline AI.')
              : ai.modelBundled
                  ? tr(context, 'Setting up the built-in AI…', 'Inihahanda ang built-in na AI…')
                  : tr(context, 'Put the AI on your phone.', 'Ilagay ang AI sa phone mo.'),
          body: ai.modelBundled
              ? tr(context,
                  'The AI and voice models came inside the app, so there is nothing to download. Bigger models below are optional.',
                  'Kasama na sa app ang AI at voice model, kaya walang ida-download. Opsyonal ang mas malalaking model sa ibaba.')
              : tr(context,
                  'One download over Wi-Fi, then it works offline forever. Your phone has ${s.device.ramLabel} of memory, so we picked a model that fits.',
                  'Isang beses na download gamit ang Wi-Fi, tapos offline na ito habambuhay. May ${s.device.ramLabel} na memory ang phone mo, kaya pinili namin ang model na kasya.'),
          extra: Column(children: [
            for (final m in kModels) _ModelCard(model: m, recommended: m.id == rec.id),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: downloading
                    ? null
                    : () async {
                        final r = await FilePicker.pickFiles(dialogTitle: 'Pick a .litertlm model');
                        final p = r.isEmpty ? null : r.first.path;
                        if (p != null) await AiService.instance.importFile(p);
                      },
                icon: const Icon(Icons.file_open_rounded),
                label: Text(tr(context, 'Import model file', 'Mag-import ng model file')),
              ),
              const Spacer(),
              if (downloading)
                TextButton(onPressed: AiService.instance.cancelDownload, child: Text(tr(context, 'Cancel', 'Kanselahin'))),
            ]),
            const SizedBox(height: 4),
            _VoiceCard(),
            const SizedBox(height: 10),
            Text(
              tr(context, 'You can skip this. Basic mode still answers from the built-in legal guide and still compares contracts.',
                  'Puwede itong laktawan. Sa basic mode, sumasagot pa rin ito mula sa legal guide at nagkukumpara pa rin ng kontrata.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            if (ai.error != null && ai.status == AiStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(ai.error!, style: TextStyle(color: KTokens.of(context).danger, fontSize: 12)),
              ),
          ]),
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.recommended});
  final ModelOption model;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ai = AiService.instance;
    final cs = Theme.of(context).colorScheme;
    final isActive = ai.active?.id == model.id;
    final installed = s.installedModelId == model.id;
    final tooBig = model.tier.index > s.device.tier.index;
    final builtIn = model.id == kBundledModelId && ai.modelBundled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        padding: const EdgeInsets.all(14),
        borderColor: recommended ? cs.primary : null,
        onTap: ai.status == AiStatus.downloading ? null : () => ai.install(model),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(model.name, style: Theme.of(context).textTheme.titleMedium)),
                if (recommended || builtIn) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(99)),
                    child: Text(builtIn ? tr(context, 'Built in', 'Kasama na') : tr(context, 'Best for you', 'Pinakaangkop'),
                        style: TextStyle(color: cs.onPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text('${builtIn ? tr(context, 'No download', 'Walang download') : model.sizeLabel} · ${s.isFil ? model.blurbFil : model.blurbEn}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              if (tooBig)
                Text(tr(context, 'May be slow or close on this phone', 'Puwedeng bumagal o mag-close sa phone na ito'),
                    style: TextStyle(color: KTokens.of(context).warning, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 10),
          if (installed && ai.ready)
            Icon(Icons.check_circle_rounded, color: KTokens.of(context).success)
          else if (isActive && ai.status == AiStatus.loading)
            const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
          else if (isActive && ai.status == AiStatus.downloading)
            SizedBox.square(dimension: 26, child: CircularProgressIndicator(value: ai.progress / 100, strokeWidth: 3))
          else
            Icon(Icons.download_rounded, color: cs.primary),
        ]),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ai = AiService.instance;
    final cs = Theme.of(context).colorScheme;
    final v = recommendedVoice(s.device.tier);
    return KCard(
      padding: const EdgeInsets.all(14),
      onTap: ai.voiceReady || ai.voiceDownloading ? null : () => ai.installVoice(v),
      child: Row(children: [
        Icon(Icons.mic_rounded, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ai.voiceBundled ? tr(context, 'Voice input', 'Boses') : tr(context, 'Voice input (optional)', 'Boses (opsyonal)'), style: Theme.of(context).textTheme.titleMedium),
            Text('${v.name} · ${ai.voiceBundled ? tr(context, 'built in', 'kasama na') : '${v.sizeMb} MB'} · ${tr(context, 'speech-to-text on your phone', 'speech-to-text sa phone mo')}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
        if (ai.voiceReady)
          Icon(Icons.check_circle_rounded, color: KTokens.of(context).success)
        else if (ai.voiceDownloading)
          SizedBox.square(dimension: 26, child: CircularProgressIndicator(value: ai.voiceProgress / 100, strokeWidth: 3))
        else
          Icon(Icons.download_rounded, color: cs.primary),
      ]),
    );
  }
}
