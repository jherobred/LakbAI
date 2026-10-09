import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../cases/cases.dart';
import '../contract/contract.dart';
import '../contract/ocr.dart';
import '../core/app_state.dart';
import '../theme.dart';
import 'compare.dart';
import 'widgets.dart';

class ScanFlowScreen extends StatefulWidget {
  const ScanFlowScreen({super.key});
  @override
  State<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends State<ScanFlowScreen> {
  final List<String> _verified = [];
  final List<String> _new = [];
  bool _working = false;
  String _stage = '';

  Future<void> _scan(List<String> target, String label) async {
    final paths = await Navigator.of(context).push<List<String>>(
      PageRouteBuilder(
        transitionDuration: Motion.d(context, 380),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: CameraScreen(label: label)),
      ),
    );
    if (paths != null && paths.isNotEmpty) setState(() => target.addAll(paths));
  }

  Future<void> _gallery(List<String> target) async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (picked.isNotEmpty) setState(() => target.addAll(picked.map((x) => x.path)));
  }

  Future<void> _useSamples() async {
    final dir = await getTemporaryDirectory();
    Future<String> copy(String asset) async {
      final data = await rootBundle.load(asset);
      final f = File('${dir.path}/${asset.split('/').last}');
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return f.path;
    }

    final v = await copy('assets/samples/verified_contract.png');
    final n = await copy('assets/samples/new_contract.png');
    setState(() {
      _verified
        ..clear()
        ..add(v);
      _new
        ..clear()
        ..add(n);
    });
  }

  Future<void> _compare() async {
    final fil = AppScope.read(context).isFil;
    setState(() {
      _working = true;
      _stage = tr(context, 'Reading the verified contract…', 'Binabasa ang na-verify na kontrata…');
    });
    try {
      final vText = await OcrService.instance.readPages(_verified);
      if (!mounted) return;
      setState(() => _stage = tr(context, 'Reading the new contract…', 'Binabasa ang bagong kontrata…'));
      final nText = await OcrService.instance.readPages(_new);
      if (!mounted) return;
      setState(() => _stage = tr(context, 'Comparing every clause…', 'Kinukumpara ang bawat sugnay…'));
      final v = extractTerms(vText);
      final n = extractTerms(nText);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _working = false);
      final confirmed = await showReviewSheet(context, v, n);
      if (confirmed != true || !mounted) return;
      setState(() {
        _working = true;
        _stage = tr(context, 'Saving evidence on your phone…', 'Itinatago ang ebidensya sa phone mo…');
      });
      final repo = CaseRepository.instance;
      final id = repo.newId();
      final pages = <EvidencePage>[
        for (final p in _verified) await repo.addEvidence(id, p, 'verified'),
        for (final p in _new) await repo.addEvidence(id, p, 'new'),
      ];
      final c = CaseFile(
        id: id,
        kind: CaseKind.substitution,
        createdAt: DateTime.now(),
        verified: v,
        current: n,
        discrepancies: compareContracts(v, n, fil: fil),
        pages: pages,
        employer: n.employer ?? v.employer ?? '',
        country: n.worksite ?? v.worksite ?? '',
      );
      await repo.save(c);
      if (!mounted) return;
      setState(() => _working = false);
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CompareScreen(caseFile: c)));
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ready = _verified.isNotEmpty && _new.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Compare contracts', 'Ikumpara ang kontrata'))),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            Text(
              tr(context, 'Photograph each page. Reading happens on this phone; nothing is uploaded.',
                  'Kunan ng litrato ang bawat pahina. Sa phone na ito binabasa; walang ina-upload.'),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _SlotCard(
              step: 1,
              title: tr(context, 'DMW-verified contract', 'Kontratang na-verify ng DMW'),
              subtitle: tr(context, 'The copy approved before you left the Philippines', 'Ang kopyang inaprubahan bago ka umalis ng Pilipinas'),
              icon: Icons.verified_rounded,
              color: KTokens.of(context).success,
              pages: _verified,
              onScan: () => _scan(_verified, tr(context, 'Verified contract', 'Na-verify na kontrata')),
              onGallery: () => _gallery(_verified),
              onRemove: (p) => setState(() => _verified.remove(p)),
            ).animate().fadeIn(duration: Motion.d(context, 350)).slideY(begin: 0.1),
            const SizedBox(height: 14),
            _SlotCard(
              step: 2,
              title: tr(context, 'New contract', 'Bagong kontrata'),
              subtitle: tr(context, 'The one you are asked to sign abroad', 'Ang pinapapirma sa iyo sa abroad'),
              icon: Icons.edit_document,
              color: KTokens.of(context).warning,
              pages: _new,
              onScan: () => _scan(_new, tr(context, 'New contract', 'Bagong kontrata')),
              onGallery: () => _gallery(_new),
              onRemove: (p) => setState(() => _new.remove(p)),
            ).animate().fadeIn(delay: 80.ms, duration: Motion.d(context, 350)).slideY(begin: 0.1),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: _useSamples,
                icon: const Icon(Icons.science_rounded),
                label: Text(tr(context, 'Try with sample contracts', 'Subukan gamit ang sample na kontrata')),
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: AnimatedOpacity(
              opacity: ready ? 1 : 0.5,
              duration: Motion.d(context, 250),
              child: FilledButton.icon(
                onPressed: ready && !_working ? _compare : null,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: Text(tr(context, 'Compare now', 'Ikumpara na')),
              ),
            ),
          ),
        ),
        if (_working) _WorkingOverlay(stage: _stage),
      ]),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.pages,
    required this.onScan,
    required this.onGallery,
    required this.onRemove,
  });
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> pages;
  final VoidCallback onScan;
  final VoidCallback onGallery;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$step. $title', style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ]),
          ),
          if (pages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
              child: Text('${pages.length} ${tr(context, 'pg', 'pahina')}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ).animate().scaleXY(begin: 0.5, curve: Curves.easeOutBack),
        ]),
        if (pages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in pages)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(p), width: 68, height: 92, fit: BoxFit.cover, cacheWidth: 160),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () => onRemove(p),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ).animate().fadeIn().scaleXY(begin: 0.8),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onScan,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(pages.isEmpty ? tr(context, 'Scan pages', 'I-scan') : tr(context, 'Add page', 'Magdagdag')),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(onPressed: onGallery, icon: const Icon(Icons.photo_library_rounded), tooltip: tr(context, 'From gallery', 'Mula sa gallery')),
        ]),
      ]),
    );
  }
}

class _WorkingOverlay extends StatelessWidget {
  const _WorkingOverlay({required this.stage});
  final String stage;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.92),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 120,
              height: 150,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline)),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var i = 0; i < 7; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        height: 6,
                        width: i.isEven ? 90 : 60,
                        decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
                      ),
                  ]),
                ),
                Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, cs.primary, Colors.transparent])))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 4, end: 144, duration: 1100.ms, curve: Curves.easeInOut),
              ]),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: Motion.d(context, 250),
              child: Text(stage, key: ValueKey(stage), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 6),
            Text(tr(context, 'On-device · offline', 'Sa phone · offline'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: Motion.d(context, 200));
  }
}

/// Lets the worker correct anything the scan misread before comparing.
Future<bool?> showReviewSheet(BuildContext context, ContractTerms v, ContractTerms n) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(v: v, n: n),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.v, required this.n});
  final ContractTerms v;
  final ContractTerms n;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  Future<void> _edit(String label, String current, void Function(String) apply) async {
    final c = TextEditingController(text: current == '—' ? '' : current);
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tr(d, 'Cancel', 'Kanselahin'))),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('OK')),
        ],
      ),
    );
    if (r != null) setState(() => apply(r.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = widget.v;
    final n = widget.n;
    String yn(bool? b) => b == null ? '—' : (b ? tr(context, 'Yes', 'Oo') : tr(context, 'No', 'Hindi'));
    bool? parseYn(String s) => s.isEmpty ? null : RegExp(r'^(y|yes|oo|meron|mayroon|true|1)', caseSensitive: false).hasMatch(s);
    int? parseInt(String s) => int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '');

    void money(ContractTerms t, String s) {
      final m = RegExp(r'([A-Za-z\$]{2,4})?\s*([0-9][0-9,]*(?:\.\d+)?)\s*([A-Za-z]{3})?').firstMatch(s);
      if (m == null) return;
      t.salary = double.tryParse(m.group(2)!.replaceAll(',', ''));
      final cur = (m.group(1) ?? m.group(3))?.toUpperCase().replaceAll('\$', 'D');
      if (cur != null && cur.length >= 3) t.currency = cur == 'USD' || cur == 'US' ? 'USD' : cur;
    }

    final rows = <(String, String, String, void Function(String), void Function(String))>[
      (tr(context, 'Salary', 'Sahod'), v.salaryLabel, n.salaryLabel, (s) => money(v, s), (s) => money(n, s)),
      (tr(context, 'Work hours / day', 'Oras ng trabaho / araw'), '${v.workHoursPerDay ?? '—'}', '${n.workHoursPerDay ?? '—'}', (s) => v.workHoursPerDay = parseInt(s), (s) => n.workHoursPerDay = parseInt(s)),
      (tr(context, 'Rest hours / day', 'Oras ng pahinga / araw'), '${v.restHoursPerDay ?? '—'}', '${n.restHoursPerDay ?? '—'}', (s) => v.restHoursPerDay = parseInt(s), (s) => n.restHoursPerDay = parseInt(s)),
      (tr(context, 'Rest days', 'Day off'), v.restDayLabel, n.restDayLabel, (s) {
        v.restDays = parseInt(s);
        v.restPeriod = s.contains('month') || s.contains('buwan') ? 'month' : 'week';
      }, (s) {
        n.restDays = parseInt(s);
        n.restPeriod = s.contains('month') || s.contains('buwan') ? 'month' : 'week';
      }),
      (tr(context, 'Paid leave (days/yr)', 'Bakasyon (araw/taon)'), '${v.leaveDays ?? '—'}', '${n.leaveDays ?? '—'}', (s) => v.leaveDays = parseInt(s), (s) => n.leaveDays = parseInt(s)),
      (tr(context, 'Length (months)', 'Haba (buwan)'), '${v.durationMonths ?? '—'}', '${n.durationMonths ?? '—'}', (s) => v.durationMonths = parseInt(s), (s) => n.durationMonths = parseInt(s)),
      (tr(context, 'Position', 'Posisyon'), v.position ?? '—', n.position ?? '—', (s) => v.position = s.isEmpty ? null : s, (s) => n.position = s.isEmpty ? null : s),
      (tr(context, 'Employer', 'Employer'), v.employer ?? '—', n.employer ?? '—', (s) => v.employer = s.isEmpty ? null : s, (s) => n.employer = s.isEmpty ? null : s),
      (tr(context, 'Worksite', 'Lugar'), v.worksite ?? '—', n.worksite ?? '—', (s) => v.worksite = s.isEmpty ? null : s, (s) => n.worksite = s.isEmpty ? null : s),
      (tr(context, 'Free food', 'Libreng pagkain'), yn(v.freeFood), yn(n.freeFood), (s) => v.freeFood = parseYn(s), (s) => n.freeFood = parseYn(s)),
      (tr(context, 'Free lodging', 'Libreng tirahan'), yn(v.freeLodging), yn(n.freeLodging), (s) => v.freeLodging = parseYn(s), (s) => n.freeLodging = parseYn(s)),
      (tr(context, 'Airfare paid', 'Bayad ang pamasahe'), yn(v.airfare), yn(n.airfare), (s) => v.airfare = parseYn(s), (s) => n.airfare = parseYn(s)),
    ];

    Widget cell(String text, VoidCallback onTap, Color tint) => Expanded(
          child: Pressable(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Icon(Icons.edit_rounded, size: 13, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      builder: (context, sc) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'Check what we read', 'I-check ang nabasa namin'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              tr(context, 'Scans can misread. Tap any value to fix it. Blank means not found.',
                  'Puwedeng magkamali ang scan. I-tap ang anumang value para itama. Blangko kung hindi nakita.'),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(flex: 4, child: SizedBox()),
              Expanded(flex: 5, child: Text(tr(context, 'Verified', 'Na-verify'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: KTokens.of(context).success))),
              Expanded(flex: 5, child: Text(tr(context, 'New', 'Bago'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: KTokens.of(context).warning))),
            ]),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final r = rows[i];
              final differs = r.$2 != r.$3 && r.$2 != '—' && r.$3 != '—';
              return Row(children: [
                Expanded(
                  flex: 4,
                  child: Row(children: [
                    if (differs) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: KTokens.of(context).danger, shape: BoxShape.circle)),
                    Flexible(child: Text(r.$1, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
                  ]),
                ),
                Expanded(flex: 10, child: Row(children: [
                  cell(r.$2, () => _edit('${r.$1} · ${tr(context, 'verified', 'na-verify')}', r.$2, r.$4), KTokens.of(context).success),
                  cell(r.$3, () => _edit('${r.$1} · ${tr(context, 'new', 'bago')}', r.$3, r.$5), KTokens.of(context).warning),
                ])),
              ]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.fact_check_rounded),
              label: Text(tr(context, 'Looks right, compare', 'Tama na, ikumpara')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Full-screen document camera with a page guide, flash and multi-page capture.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.label});
  final String label;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  final List<String> _shots = [];
  bool _torch = false;
  bool _flashing = false;
  String? _error;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final low = AppScope.read(context).device.tier == DeviceTier.low;
      final c = CameraController(back, low ? ResolutionPreset.high : ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      await c.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() => _cam = c);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _cam;
    if (c == null || c.value.isTakingPicture) return;
    HapticFeedback.mediumImpact();
    setState(() => _flashing = true);
    try {
      final x = await c.takePicture();
      setState(() => _shots.add(x.path));
    } finally {
      if (mounted) setState(() => _flashing = false);
    }
  }

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    _torch = !_torch;
    await c.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _focus(TapDownDetails d, BoxConstraints box) async {
    final c = _cam;
    if (c == null) return;
    final p = Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight);
    setState(() => _focusPoint = d.localPosition);
    try {
      await c.setFocusPoint(p);
      await c.setExposurePoint(p);
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    final reduced = Motion.reduced(context);
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          if (c != null && c.value.isInitialized)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  onTapDown: (d) => _focus(d, box),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: box.maxWidth,
                      height: box.maxWidth * c.value.aspectRatio,
                      child: CameraPreview(c),
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.white)))
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          // Page guide
          IgnorePointer(
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth * 0.84;
              final h = w * 1.38;
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(children: [
                    CustomPaint(size: Size(w, h), painter: _CornerPainter()),
                    if (!reduced)
                      Container(height: 2, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, KColors.cyan, Colors.transparent])))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(begin: 10, end: h - 10, duration: 2200.ms, curve: Curves.easeInOut),
                  ]),
                ),
              );
            }),
          ),
          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ).animate().scaleXY(begin: 1.4, end: 1, duration: 220.ms).fadeIn(),
            ),
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context, _shots), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                Expanded(
                  child: Column(children: [
                    Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(tr(context, 'Fit one page inside the frame', 'Ipasok ang isang pahina sa frame'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ]),
                ),
                IconButton(onPressed: _toggleTorch, icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white)),
              ]),
            ),
          ),
          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: _shots.isEmpty
                        ? const SizedBox()
                        : Stack(clipBehavior: Clip.none, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_shots.last), width: 56, height: 64, fit: BoxFit.cover, cacheWidth: 140),
                            ).animate(key: ValueKey(_shots.length)).scaleXY(begin: 1.6, curve: Curves.easeOutCubic, duration: 320.ms).fadeIn(),
                            Positioned(
                              right: 0,
                              top: -6,
                              child: CircleAvatar(radius: 11, backgroundColor: KColors.lPrimary, child: Text('${_shots.length}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800))),
                            ),
                          ]),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: _capture,
                    scale: 0.9,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      padding: const EdgeInsets.all(5),
                      child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 64,
                    child: AnimatedOpacity(
                      opacity: _shots.isEmpty ? 0 : 1,
                      duration: Motion.d(context, 200),
                      child: TextButton(
                        onPressed: _shots.isEmpty ? null : () => Navigator.pop(context, _shots),
                        child: Text(tr(context, 'Done', 'Tapos'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flashing ? 0.85 : 0,
              duration: const Duration(milliseconds: 90),
              child: Container(color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0;
    const r = 16.0;
    final w = size.width;
    final h = size.height;
    // dim outside
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)), Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(l, 0)
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, l)
      ..moveTo(w, h - l)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - l, h)
      ..moveTo(l, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
