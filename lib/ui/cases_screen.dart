import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../cases/cases.dart';
import '../core/app_state.dart';
import '../theme.dart';
import 'compare.dart';
import 'report.dart';
import 'widgets.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  late Future<List<CaseFile>> _cases = CaseRepository.instance.list();

  void _reload() => setState(() => _cases = CaseRepository.instance.list());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'My saved cases', 'Mga naitalang kaso'))),
      body: FutureBuilder<List<CaseFile>>(
        future: _cases,
        builder: (context, snap) {
          final list = snap.data ?? const [];
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(tr(context, 'Nothing saved yet', 'Wala pang naitala'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    tr(context, 'Compared contracts and reports are kept here, only on this phone.', 'Dito nakatago ang mga naikumparang kontrata at report, sa phone lang na ito.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = list[i];
              final sub = c.kind == CaseKind.substitution;
              final color = sub ? (c.worseCount > 0 ? t.danger : t.success) : t.warning;
              final d = c.createdAt;
              return Dismissible(
                key: ValueKey(c.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async => await showDialog<bool>(
                  context: context,
                  builder: (c2) => AlertDialog(
                    title: Text(tr(c2, 'Delete this case?', 'Burahin ang kasong ito?')),
                    content: Text(tr(c2, 'Its photos and report will be removed from this phone. This cannot be undone.', 'Mabubura ang mga litrato at report nito sa phone. Hindi na ito maibabalik.')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c2, false), child: Text(tr(c2, 'Keep', 'Itago'))),
                      FilledButton(onPressed: () => Navigator.pop(c2, true), child: Text(tr(c2, 'Delete', 'Burahin'))),
                    ],
                  ),
                ),
                onDismissed: (_) async {
                  await CaseRepository.instance.delete(c);
                  _reload();
                },
                child: KCard(
                  onTap: () => openPage(context, sub ? CompareScreen(caseFile: c) : ReportScreen(caseFile: c, kind: c.kind)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                      child: Icon(sub ? Icons.compare_arrows_rounded : Icons.person_search_rounded, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          sub
                              ? tr(context, '${c.worseCount} change(s) against you', '${c.worseCount} pagbabagong ikalulugi mo')
                              : tr(context, '${c.redFlags.length} recruiter warning sign(s)', '${c.redFlags.length} babala sa recruiter'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${tr(context, 'Case', 'Kaso')} ${c.id} · ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} · ${c.pages.length} ${tr(context, 'photo(s)', 'litrato')}',
                            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                  ]),
                ),
              ).animate().fadeIn(delay: (i.clamp(0, 8) * 50).ms, duration: Motion.d(context, 260));
            },
          );
        },
      ),
    );
  }
}
