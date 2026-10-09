import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cases/cases.dart';
import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../theme.dart';
import 'chat.dart';
import 'report.dart';
import 'widgets.dart';

class _Q {
  const _Q(this.en, this.fil, this.weight, {this.urgent = false, this.kb});
  final String en;
  final String fil;
  final int weight;
  final bool urgent;
  final String? kb;
}

const _questions = [
  _Q('They could not show a DMW license, or the office is not a licensed address', 'Hindi sila nakapagpakita ng lisensya mula DMW, o hindi lisensyado ang opisina', 3, kb: 'verify_license'),
  _Q('They asked for money before a job offer, or gave no official receipt', 'Naningil sila bago may job offer, o walang opisyal na resibo', 3, kb: 'fees_hsw'),
  _Q('I am a household worker and was charged a placement fee', 'Kasambahay ako at siningil ng placement fee', 3, kb: 'fees_hsw'),
  _Q('They told me to leave as a tourist or to lie at immigration', 'Pinaalis ako bilang turista o pinagsinungaling sa immigration', 5, urgent: true, kb: 'trafficking'),
  _Q('They keep my passport or documents until I pay', 'Hawak nila ang passport o dokumento ko hangga\'t hindi ako nagbabayad', 4, kb: 'withholding_documents'),
  _Q('We only talk through Facebook, WhatsApp or text', 'Sa Facebook, WhatsApp o text lang kami nag-uusap', 2, kb: 'recruiter_red_flags'),
  _Q('The job they described is different from my visa or contract', 'Iba ang trabahong sinabi nila sa nasa visa o kontrata ko', 3, kb: 'substitution_definition'),
  _Q('I must repay costs through salary deductions abroad', 'Babayaran ko ang gastos sa pamamagitan ng kaltas sa sahod sa abroad', 2, kb: 'fees_hsw'),
  _Q('I am leaving without DMW processing or an OFW Pass', 'Aalis ako nang walang proseso ng DMW o OFW Pass', 3, kb: 'recruiter_red_flags'),
  _Q('They threatened me or my family', 'Pinagbantaan nila ako o ang pamilya ko', 5, urgent: true, kb: 'trafficking'),
];

class RecruiterCheckScreen extends StatefulWidget {
  const RecruiterCheckScreen({super.key});
  @override
  State<RecruiterCheckScreen> createState() => _RecruiterCheckScreenState();
}

class _RecruiterCheckScreenState extends State<RecruiterCheckScreen> {
  final Set<int> _yes = {};

  int get _score => _yes.fold(0, (s, i) => s + _questions[i].weight);
  bool get _urgent => _yes.any((i) => _questions[i].urgent);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final fil = AppScope.of(context).isFil;
    final score = _score;
    final (Color c, String label, String advice) = _urgent || score >= 7
        ? (t.danger, tr(context, 'High risk', 'Mataas na panganib'),
            tr(context, 'Do not pay or hand over documents. Report it: DMW (1348) or the 1343 Actionline.', 'Huwag magbayad o magbigay ng dokumento. I-report: DMW (1348) o 1343 Actionline.'))
        : score >= 3
            ? (t.warning, tr(context, 'Warning signs', 'May babala'),
                tr(context, 'Verify the agency license on dmw.gov.ph before paying anything, and keep screenshots.', 'I-verify ang lisensya sa dmw.gov.ph bago magbayad, at mag-screenshot.'))
            : (t.success, tr(context, 'No major signs yet', 'Wala pang malaking babala'),
                tr(context, 'Still verify the license and get official receipts for every payment.', 'I-verify pa rin ang lisensya at humingi ng resibo sa bawat bayad.'));
    final meter = (score / 14).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Check my recruiter', 'I-check ang recruiter'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        children: [
          Text(tr(context, 'Tick anything that happened to you. Nothing leaves your phone.', 'I-tick ang anumang nangyari sa iyo. Walang lalabas sa phone mo.'),
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: Motion.d(context, 350),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(22), border: Border.all(color: c.withValues(alpha: 0.45))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_urgent || score >= 7 ? Icons.gpp_bad_rounded : (score >= 3 ? Icons.gpp_maybe_rounded : Icons.gpp_good_rounded), color: c),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: Motion.d(context, 250),
                  child: Text(label, key: ValueKey(label), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: c)),
                ),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _urgent ? 1 : meter),
                  duration: Motion.d(context, 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: c, backgroundColor: c.withValues(alpha: 0.15)),
                ),
              ),
              const SizedBox(height: 10),
              Text(advice, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_urgent) const Padding(padding: EdgeInsets.only(top: 12), child: EmergencyBanner()),
          const SizedBox(height: 12),
          for (final (i, q) in _questions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                borderColor: _yes.contains(i) ? c.withValues(alpha: 0.6) : null,
                child: Row(children: [
                  Checkbox(
                    value: _yes.contains(i),
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => v == true ? _yes.add(i) : _yes.remove(i));
                    },
                  ),
                  Expanded(child: Text(fil ? q.fil : q.en, style: const TextStyle(fontSize: 14.5, height: 1.3))),
                  if (q.kb != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
                      onPressed: () {
                        final e = KnowledgeBase.instance.byId(q.kb!);
                        if (e != null) showKbSheet(context, e);
                      },
                    ),
                ]),
              ).animate().fadeIn(delay: (i * 40).ms, duration: Motion.d(context, 300)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _yes.isEmpty
                ? null
                : () {
                    final c = CaseFile(
                      id: CaseRepository.instance.newId(),
                      kind: CaseKind.recruiter,
                      createdAt: DateTime.now(),
                      redFlags: [for (final i in _yes) fil ? _questions[i].fil : _questions[i].en],
                      level: _urgent ? 6 : 1,
                    );
                    openPage(context, ReportScreen(caseFile: c, kind: CaseKind.recruiter));
                  },
            icon: const Icon(Icons.description_rounded),
            label: Text(tr(context, 'Record this and make a report', 'Itala at gumawa ng report')),
          ),
        ),
      ),
    );
  }
}
