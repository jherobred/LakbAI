import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai_service.dart';
import '../ai/prompts.dart';
import '../cases/cases.dart';
import '../cases/report_pdf.dart';
import '../core/app_state.dart';
import '../theme.dart';
import 'voice.dart';
import 'widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.caseFile, this.kind = CaseKind.substitution});
  final CaseFile? caseFile;
  final CaseKind kind;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final CaseFile _c;
  final _name = TextEditingController();
  final _agency = TextEditingController();
  final _employer = TextEditingController();
  final _country = TextEditingController();
  final _date = TextEditingController();
  final _place = TextEditingController();
  final _statement = TextEditingController();
  bool _polishing = false;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    _c = widget.caseFile ??
        CaseFile(id: CaseRepository.instance.newId(), kind: widget.kind, createdAt: DateTime.now());
    _name.text = _c.workerName;
    _agency.text = _c.agency;
    _employer.text = _c.employer;
    _country.text = _c.country;
    _date.text = _c.incidentDate;
    _place.text = _c.incidentPlace;
    _statement.text = _c.statement;
  }

  @override
  void dispose() {
    for (final c in [_name, _agency, _employer, _country, _date, _place, _statement]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _dictate() async {
    final t = await showVoiceSheet(context);
    if (t == null || t.isEmpty) return;
    setState(() => _statement.text = _statement.text.isEmpty ? t : '${_statement.text}\n$t');
  }

  Future<void> _polish() async {
    final raw = _statement.text.trim();
    if (raw.isEmpty || !AiService.instance.ready) return;
    final fil = AppScope.read(context).isFil;
    setState(() => _polishing = true);
    try {
      final out = await AiService.instance.complete(
        system: 'You turn spoken notes into clear written statements. Never add or change facts.',
        prompt: statementPrompt(rawText: raw, fil: fil),
        maxOutputTokens: 480,
      );
      if (out.isNotEmpty && mounted) setState(() => _statement.text = out);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _build() async {
    final fil = AppScope.read(context).isFil;
    setState(() => _building = true);
    _c
      ..workerName = _name.text.trim()
      ..agency = _agency.text.trim()
      ..employer = _employer.text.trim()
      ..country = _country.text.trim()
      ..incidentDate = _date.text.trim()
      ..incidentPlace = _place.text.trim()
      ..statement = _statement.text.trim();
    try {
      await CaseRepository.instance.save(_c);
      final file = await ReportPdf.build(_c, fil: fil);
      if (!mounted) return;
      setState(() => _building = false);
      await _done(file);
    } catch (e) {
      if (mounted) {
        setState(() => _building = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _done(File file) {
    final t = KTokens.of(context);
    return showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.task_alt_rounded, size: 64, color: t.success).animate().scaleXY(begin: 0.4, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 12),
            Text(tr(c, 'Your report is ready', 'Handa na ang report mo'), style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              tr(c, 'Saved on this phone only. Share it only when it is safe, for example with the MWO, DMW, a lawyer or family you trust.',
                  'Nasa phone mo lang ito. Ibahagi lang kapag ligtas, halimbawa sa MWO, DMW, abogado o pamilyang pinagkakatiwalaan.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(file.path.split('/').last, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Kontrata incident report')),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(tr(c, 'Share or save PDF', 'I-share o i-save ang PDF')),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tr(c, 'Done', 'Tapos'))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ai = AiService.instance;
    Widget field(TextEditingController c, String label, IconData icon, {String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Formal report', 'Pormal na report'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          KCard(
            color: cs.primaryContainer.withValues(alpha: 0.45),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.shield_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(context, 'Every field is optional. The PDF is made on this phone and includes your evidence fingerprints, the laws involved, and where to file.',
                      'Opsyonal ang lahat ng field. Sa phone na ito ginagawa ang PDF, kasama ang fingerprint ng ebidensya, mga batas, at kung saan isasampa.'),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ]),
          ),
          if (_c.discrepancies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              tr(context, '${_c.worseCount} contract change(s) and ${_c.pages.length} photo(s) will be included.',
                  'Kasama ang ${_c.worseCount} pagbabago sa kontrata at ${_c.pages.length} litrato.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ],
          SectionLabel(tr(context, 'Details', 'Mga detalye')),
          field(_name, tr(context, 'Your name (optional)', 'Pangalan mo (opsyonal)'), Icons.person_rounded),
          field(_agency, tr(context, 'Agency or recruiter', 'Ahensya o recruiter'), Icons.apartment_rounded),
          field(_employer, tr(context, 'Employer', 'Employer'), Icons.badge_rounded),
          field(_country, tr(context, 'Country / worksite', 'Bansa / lugar ng trabaho'), Icons.public_rounded),
          field(_date, tr(context, 'When did it happen?', 'Kailan nangyari?'), Icons.event_rounded, hint: tr(context, 'e.g. 12 Sept 2026', 'hal. 12 Set 2026')),
          field(_place, tr(context, 'Where did it happen?', 'Saan nangyari?'), Icons.place_rounded, hint: tr(context, 'e.g. agency office in Riyadh', 'hal. opisina ng ahensya sa Riyadh')),
          SectionLabel(tr(context, 'What happened, in your words', 'Ano ang nangyari, sa sarili mong salita')),
          TextField(
            controller: _statement,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: tr(context, 'Who asked you to sign, what they said, what changed, and whether you were pressured.',
                  'Sino ang nagpapirma, ano ang sinabi nila, ano ang binago, at kung pinilit ka.'),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _dictate, icon: const Icon(Icons.mic_rounded), label: Text(tr(context, 'Speak it', 'Sabihin'))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListenableBuilder(
                listenable: ai,
                builder: (context, _) => OutlinedButton.icon(
                  onPressed: ai.ready && !_polishing ? _polish : null,
                  icon: _polishing ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(tr(context, 'Tidy with AI', 'Ayusin ng AI')),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            tr(context, 'AI tidies your words offline. It keeps every fact, name and number as you gave them. Read it before you sign.',
                'Inaayos ng AI ang salita mo nang offline. Hindi nito binabago ang mga fact, pangalan at numero. Basahin muna bago pumirma.'),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _building ? null : _build,
            icon: _building ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(tr(context, 'Create PDF report', 'Gumawa ng PDF report')),
          ),
        ),
      ),
    );
  }
}
