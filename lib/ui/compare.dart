import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai/ai_service.dart';
import '../ai/prompts.dart';
import '../cases/cases.dart';
import '../contract/contract.dart';
import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../theme.dart';
import 'ai_widgets.dart';
import 'chat.dart';
import 'ladder.dart';
import 'report.dart';
import 'widgets.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.caseFile});
  final CaseFile caseFile;
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String _explanation = '';
  bool _explaining = false;

  Color _sev(BuildContext c, Severity s) {
    final t = KTokens.of(c);
    return switch (s) {
      Severity.high => t.danger,
      Severity.medium => t.warning,
      Severity.info => Theme.of(c).colorScheme.primary,
      Severity.better => t.success,
    };
  }

  Future<void> _explain() async {
    final fil = AppScope.read(context).isFil;
    final d = widget.caseFile.discrepancies;
    setState(() {
      _explaining = true;
      _explanation = '';
    });
    final ai = AiService.instance;
    try {
      if (ai.ready && d.isNotEmpty) {
        // Keep the raw stream and show a cleaned copy, so line breaks between tokens survive.
        final raw = StringBuffer();
        await for (final t in ai.ask(
          system: systemPrompt(fil: fil),
          prompt: explainChangesPrompt(diffSummary: diffSummaryForModel(d), fil: fil),
          maxOutputTokens: 260,
        )) {
          raw.write(t);
          setState(() => _explanation = cleanModelText(raw.toString()));
        }
      }
      if (_explanation.trim().isEmpty) {
        _explanation = _templateExplanation(fil);
      }
    } catch (_) {
      _explanation = _templateExplanation(fil);
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  String _templateExplanation(bool fil) {
    final worse = widget.caseFile.discrepancies.where((x) => x.severity == Severity.high || x.severity == Severity.medium).toList();
    if (worse.isEmpty) {
      return fil
          ? 'Walang nakitang pagbabagong ikalulugi mo. Itago pa rin ang dalawang kontrata.'
          : 'No changes against you were found. Keep both contracts anyway.';
    }
    final items = worse.map((x) => '• ${x.title(fil)} (${x.before} → ${x.after})').join('\n');
    return fil
        ? 'Binago ang kontrata mo sa ${worse.length} paraan na ikalulugi mo:\n$items\n\nBawal ito kung walang pahintulot ng DMW. Mananagot din ang ahensya mo sa Pilipinas, at may 3 taon ka para habulin ang pera. Ligtas mong maitatago ang ebidensyang ito at magpasya mamaya.'
        : 'Your contract was changed in ${worse.length} way(s) that hurt you:\n$items\n\nThis is not allowed without DMW approval. Your Philippine agency is also liable, and you have 3 years to claim the money. You can keep this evidence safely and decide later.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final fil = AppScope.of(context).isFil;
    final c = widget.caseFile;
    final worse = c.worseCount;
    final d = Motion.d(context, 420);
    final heroGradient = worse > 0
        ? LinearGradient(colors: [t.danger, const Color(0xFFB91C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : LinearGradient(colors: [t.success, const Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'What changed', 'Ano ang binago'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(26)),
            child: Row(children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: worse),
                duration: Motion.d(context, 900),
                builder: (context, v, _) => Text('$v', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    worse == 0
                        ? tr(context, 'No changes against you', 'Walang pagbabagong ikalulugi mo')
                        : tr(context, worse == 1 ? 'change against you' : 'changes against you', 'pagbabagong ikalulugi mo'),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(tr(context, 'Saved privately on this phone · Case ${c.id}', 'Nakatago sa phone mo · Kaso ${c.id}'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ).animate().fadeIn(duration: d).scaleXY(begin: 0.95, curve: Curves.easeOutBack),
          if (c.discrepancies.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SeverityStrip(discrepancies: c.discrepancies, colorOf: (s) => _sev(context, s)).animate().fadeIn(duration: d, delay: 100.ms),
          ],
          const SizedBox(height: 14),
          if (c.discrepancies.isEmpty)
            KCard(
              child: Text(tr(context, 'We could not find differences in the parts we could read. Check the papers yourself too, especially pages that were hard to scan.',
                  'Wala kaming nakitang pagkakaiba sa mga nabasa namin. I-check mo rin mismo ang papel, lalo na ang mga pahinang mahirap basahin.')),
            ),
          for (final (i, x) in c.discrepancies.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DiffCard(d: x, color: _sev(context, x.severity), fil: fil)
                  .animate()
                  .fadeIn(delay: (120 + i * 90).ms, duration: d)
                  .slideX(begin: 0.12, curve: Curves.easeOutCubic),
            ),
          const SizedBox(height: 4),
          KCard(
            color: cs.primaryContainer.withValues(alpha: 0.45),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(tr(context, 'What this means for you', 'Ano ang ibig sabihin nito sa iyo'), style: Theme.of(context).textTheme.titleMedium)),
              ]),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: Motion.d(context, 250),
                child: _explanation.isEmpty
                    ? FilledButton.tonalIcon(
                        onPressed: _explaining ? null : _explain,
                        icon: _explaining
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.record_voice_over_rounded),
                        label: Text(tr(context, 'Explain in simple words', 'Ipaliwanag sa simpleng salita')),
                      )
                    : MarkdownText(_explanation),
              ),
              if (_explanation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  AiService.instance.ready ? tr(context, 'Written offline by on-device AI', 'Isinulat offline ng AI sa phone') : tr(context, 'From the built-in legal guide', 'Mula sa legal guide'),
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openPage(context, LadderScreen(caseFile: c)),
                icon: const Icon(Icons.route_rounded),
                label: Text(tr(context, 'My options', 'Mga hakbang')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => openPage(context, ReportScreen(caseFile: c)),
                icon: const Icon(Icons.description_rounded),
                label: Text(tr(context, 'Make report', 'Gumawa ng report')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.d, required this.color, required this.fil});
  final Discrepancy d;
  final Color color;
  final bool fil;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(22)),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.title(fil), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Val(label: tr(context, 'Verified', 'Na-verify'), value: d.before, color: KTokens.of(context).success)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, color: color)
                          .animate(onPlay: (c) => Motion.reduced(context) ? null : c.repeat(reverse: true))
                          .moveX(begin: -2, end: 3, duration: 700.ms),
                    ),
                    Expanded(child: _Val(label: tr(context, 'New', 'Bago'), value: d.after, color: color)),
                  ]),
                  if ((_firstNumber(d.before), _firstNumber(d.after)) case (final a?, final b?) when a > 0 && b > 0 && a != b) ...[
                    const SizedBox(height: 12),
                    _NumberBars(before: a, after: b, color: color),
                  ],
                  const SizedBox(height: 10),
                  Text(d.note(fil), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5, height: 1.4)),
                  if (d.kbIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final id in d.kbIds.toSet())
                        if (KnowledgeBase.instance.byId(id) case final e?)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(Icons.gavel_rounded, size: 14, color: cs.primary),
                            label: Text(e.sourceLabel, style: const TextStyle(fontSize: 11.5)),
                            onPressed: () => showKbSheet(context, e),
                          ),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Val extends StatelessWidget {
  const _Val({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

double? _firstNumber(String s) {
  final m = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', ''));
}

/// Verified value against the new one as two bars, so a cut is visible at a glance.
class _NumberBars extends StatelessWidget {
  const _NumberBars({required this.before, required this.after, required this.color});
  final double before;
  final double after;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = before > after ? before : after;
    final pct = ((after - before) / before * 100).round();
    Widget bar(String label, double v, Color c, int delay) => Row(children: [
          SizedBox(width: 64, child: Text(label, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant))),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: v / max),
              duration: Motion.d(context, 900 + delay),
              curve: Curves.easeOutCubic,
              builder: (context, f, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: f.clamp(0.02, 1.0),
                  child: Container(height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99))),
                ),
              ),
            ),
          ),
        ]);
    return Column(children: [
      bar(tr(context, 'Verified', 'Na-verify'), before, KTokens.of(context).success, 0),
      const SizedBox(height: 6),
      bar(tr(context, 'New', 'Bago'), after, color, 200),
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${pct > 0 ? '+' : ''}$pct%', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 12.5)),
        ),
      ),
    ]);
  }
}

/// One segmented bar showing how many changes are serious, minor, neutral or better.
class _SeverityStrip extends StatelessWidget {
  const _SeverityStrip({required this.discrepancies, required this.colorOf});
  final List<Discrepancy> discrepancies;
  final Color Function(Severity) colorOf;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = {for (final s in Severity.values) s: discrepancies.where((d) => d.severity == s).length}..removeWhere((_, n) => n == 0);
    String label(Severity s) => switch (s) {
          Severity.high => tr(context, 'Serious', 'Malubha'),
          Severity.medium => tr(context, 'Check', 'Suriin'),
          Severity.info => tr(context, 'Info', 'Impormasyon'),
          Severity.better => tr(context, 'Better', 'Mas maganda'),
        };
    return KCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Row(children: [
            for (final e in counts.entries) Expanded(flex: e.value, child: Container(height: 10, color: colorOf(e.key))),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final e in counts.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${e.value} ${label(e.key)}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ]),
        ]),
      ]),
    );
  }
}
