import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cases/cases.dart';
import '../core/app_state.dart';
import '../theme.dart';
import 'report.dart';
import 'widgets.dart';

class _Step {
  const _Step(this.level, this.icon, this.titleEn, this.titleFil, this.bodyEn, this.bodyFil, this.riskEn, this.riskFil);
  final int level;
  final IconData icon;
  final String titleEn;
  final String titleFil;
  final String bodyEn;
  final String bodyFil;
  final String riskEn;
  final String riskFil;
}

const _steps = [
  _Step(1, Icons.lock_rounded, 'Keep it quiet', 'Itago muna',
      'Your evidence stays on this phone. Nothing is sent anywhere. Your money claim stays alive for 3 years, so you can finish your contract and decide at home.',
      'Nasa phone mo lang ang ebidensya. Walang ipinapadala. Buhay ang karapatan mong humabol ng pera nang 3 taon, kaya puwede mong tapusin ang kontrata at magpasya pag-uwi.',
      'No one is told', 'Walang sasabihan'),
  _Step(2, Icons.phone_in_talk_rounded, 'Ask privately', 'Magtanong nang pribado',
      'Call 1348 (DMW/OWWA, 24/7) and just ask. Calling is not filing a case.',
      'Tumawag sa 1348 (DMW/OWWA, 24/7) at magtanong lang. Hindi pagsasampa ng kaso ang pagtawag.',
      'Private call', 'Pribadong tawag'),
  _Step(3, Icons.do_not_touch_rounded, 'Refuse or ask for a check', 'Tumanggi o ipa-check',
      'You can decline to sign, or ask the Migrant Workers Office at the embassy to check the new contract before or after signing.',
      'Puwede kang tumangging pumirma, o ipa-check sa Migrant Workers Office sa embahada ang bagong kontrata bago o pagkatapos pumirma.',
      'Employer may notice', 'Puwedeng mapansin ng employer'),
  _Step(4, Icons.payments_rounded, 'Get your money back', 'Habulin ang pera',
      'SEnA mediation (30 days) at the DMW or NLRC, then a money claim before an NLRC Labor Arbiter. Your Philippine agency is liable too, even for changes made abroad.',
      'SEnA mediation (30 araw) sa DMW o NLRC, saka money claim sa Labor Arbiter ng NLRC. Mananagot din ang ahensya mo sa Pilipinas, kahit binago ang kontrata sa abroad.',
      'Formal, can be done after you return', 'Pormal, puwede pag-uwi na'),
  _Step(5, Icons.gavel_rounded, 'File against the agency', 'Magsampa laban sa ahensya',
      'An administrative case at the DMW Adjudication Office can suspend or cancel the agency\'s license.',
      'Ang administratibong kaso sa DMW Adjudication Office ay puwedeng magsuspinde o magkansela ng lisensya ng ahensya.',
      'Formal', 'Pormal'),
  _Step(6, Icons.local_police_rounded, 'Criminal case or trafficking report', 'Kasong kriminal o report ng trafficking',
      'Illegal recruitment complaints go to the DMW, NBI or a prosecutor. For trafficking or forced labor, call 1343.',
      'Ang reklamo ng illegal recruitment ay sa DMW, NBI o piskal. Para sa trafficking o sapilitang trabaho, tumawag sa 1343.',
      'Most formal', 'Pinakapormal'),
];

class LadderScreen extends StatefulWidget {
  const LadderScreen({super.key, this.caseFile, this.scrollToHotlines = false});
  final CaseFile? caseFile;
  final bool scrollToHotlines;
  @override
  State<LadderScreen> createState() => _LadderScreenState();
}

class _LadderScreenState extends State<LadderScreen> {
  int _picked = 1;
  final _hotlinesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _picked = widget.caseFile?.level ?? 1;
    if (widget.scrollToHotlines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _hotlinesKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      });
    }
  }

  Future<void> _pick(int level) async {
    HapticFeedback.selectionClick();
    setState(() => _picked = level);
    final c = widget.caseFile;
    if (c != null) {
      c.level = level;
      await CaseRepository.instance.save(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final fil = AppScope.of(context).isFil;
    final d = Motion.d(context, 380);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Your options', 'Mga pagpipilian mo'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            tr(context, 'From quietest to most formal. You choose. Every step is optional, and keeping your evidence quietly is always a valid choice.',
                'Mula pinakatahimik hanggang pinakapormal. Ikaw ang pipili. Opsyonal ang bawat hakbang, at laging tamang pagpipilian ang tahimik na pagtatago ng ebidensya.'),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
          const SizedBox(height: 16),
          for (final (i, s) in _steps.indexed)
            _StepTile(
              step: s,
              fil: fil,
              selected: _picked == s.level,
              last: i == _steps.length - 1,
              onTap: () => _pick(s.level),
            ).animate().fadeIn(delay: (i * 70).ms, duration: d).slideX(begin: 0.08, curve: Curves.easeOutCubic),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => openPage(context, ReportScreen(caseFile: widget.caseFile)),
            icon: const Icon(Icons.description_rounded),
            label: Text(tr(context, 'Prepare a formal report', 'Maghanda ng pormal na report')),
          ),
          Padding(
            key: _hotlinesKey,
            padding: EdgeInsets.zero,
            child: SectionLabel(tr(context, 'Hotlines (work offline, need signal to call)', 'Mga hotline (kailangan ng signal para tumawag)')),
          ),
          _Hotline(
            name: 'DMW / OWWA',
            number: '1348',
            dial: '+6321348',
            desc: tr(context, '24/7 help, contract problems, repatriation', '24/7 na tulong, problema sa kontrata, pagpapauwi'),
            color: cs.primary,
          ),
          const SizedBox(height: 10),
          _Hotline(
            name: '1343 Actionline (IACAT)',
            number: '1343',
            dial: '+6321343',
            desc: tr(context, 'Trafficking and illegal recruitment', 'Trafficking at illegal recruitment'),
            color: t.danger,
          ),
          const SizedBox(height: 10),
          KCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.account_balance_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(context, 'Abroad, go to the Migrant Workers Office (MWO) at the Philippine embassy or consulate. Ask for shelter if you are not safe.',
                      'Sa abroad, pumunta sa Migrant Workers Office (MWO) sa embahada o konsulado ng Pilipinas. Humingi ng shelter kung hindi ka ligtas.'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.fil, required this.selected, required this.last, required this.onTap});
  final _Step step;
  final bool fil;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final hue = Color.lerp(t.success, t.danger, (step.level - 1) / 5)!;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            AnimatedContainer(
              duration: Motion.d(context, 250),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? hue : hue.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                boxShadow: selected && !Motion.reduced(context) ? [BoxShadow(color: hue.withValues(alpha: 0.4), blurRadius: 12)] : null,
              ),
              alignment: Alignment.center,
              child: Text('${step.level}', style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : hue)),
            ),
            if (!last) Expanded(child: Container(width: 2, color: cs.outlineVariant)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: KCard(
              onTap: onTap,
              padding: const EdgeInsets.all(14),
              borderColor: selected ? hue : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(step.icon, color: hue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(fil ? step.titleFil : step.titleEn, style: Theme.of(context).textTheme.titleMedium)),
                  AnimatedSwitcher(
                    duration: Motion.d(context, 200),
                    child: selected ? Icon(Icons.check_circle_rounded, color: hue, key: const ValueKey('y')) : const SizedBox(key: ValueKey('n')),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(fil ? step.bodyFil : step.bodyEn, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.4)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: hue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                  child: Text(fil ? step.riskFil : step.riskEn, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: hue)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Hotline extends StatelessWidget {
  const _Hotline({required this.name, required this.number, required this.dial, required this.desc, required this.color});
  final String name;
  final String number;
  final String dial;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(number, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(desc, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            Text(tr(context, 'From abroad: +63 2 $number', 'Mula abroad: +63 2 $number'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: color),
          onPressed: () => callNumber(context, dial),
          icon: const Icon(Icons.call_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}
