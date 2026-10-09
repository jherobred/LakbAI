import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../knowledge/topics.dart';
import 'chat.dart';
import 'widgets.dart';

class RightsScreen extends StatefulWidget {
  const RightsScreen({super.key});
  @override
  State<RightsScreen> createState() => _RightsScreenState();
}

class _RightsScreenState extends State<RightsScreen> {
  String? _topic;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fil = AppScope.of(context).isFil;
    final kb = KnowledgeBase.instance;
    final query = _q.text.trim();
    List<KbEntry> list;
    if (query.isNotEmpty) {
      list = kb.search(query, topics: {if (_topic != null) _topic!}, k: 12);
    } else if (_topic != null) {
      list = kb.byTopic(_topic!);
    } else {
      list = kb.entries;
    }
    final used = {for (final e in kb.entries) ...e.topics};
    final topics = kTopics.where((t) => used.contains(t.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Know your rights', 'Alamin ang karapatan mo'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr(context, 'Search, e.g. passport, sahod, day off', 'Maghanap, hal. passport, sahod, day off'),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final t in topics)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: TopicChip(topic: t, active: _topic == t.id, onTap: () => setState(() => _topic = _topic == t.id ? null : t.id)),
                ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.d(context, 250),
            child: ListView.separated(
              key: ValueKey('$_topic|$query'),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(kb.disclaimer(fil), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                  );
                }
                final e = list[i];
                return KCard(
                  onTap: () => showKbSheet(context, e),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title(fil), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(e.body(fil), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.gavel_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(e.sourceLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary), overflow: TextOverflow.ellipsis)),
                    ]),
                  ]),
                ).animate().fadeIn(delay: (i.clamp(0, 8) * 40).ms, duration: Motion.d(context, 260)).slideY(begin: 0.06);
              },
            ),
          ),
        ),
      ]),
    );
  }
}
