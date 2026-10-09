import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai/ai_service.dart';
import '../ai/prompts.dart';
import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../knowledge/topics.dart';
import '../theme.dart';
import 'cases_screen.dart';
import 'ladder.dart';
import 'recruiter.dart';
import 'rights.dart';
import 'scan.dart';
import 'settings.dart';
import 'voice.dart';
import 'widgets.dart';

class ChatMessage {
  ChatMessage({required this.fromUser, required String text, this.topics = const {}, this.sources = const [], this.streaming = false})
      : text = ValueNotifier(text),
        id = '${DateTime.now().microsecondsSinceEpoch}';
  final String id;
  final bool fromUser;
  final ValueNotifier<String> text;
  final Set<String> topics;
  List<String> sources;
  bool streaming;
  bool animated = false;
}

/// Highlights topic keywords inside the text field as the user types.
class KeywordController extends TextEditingController {
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final hits = KeywordDetector.instance.detect(text);
    if (hits.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final spans = <TextSpan>[];
    var i = 0;
    for (final h in hits) {
      if (h.start > i) spans.add(TextSpan(text: text.substring(i, h.start)));
      spans.add(TextSpan(
        text: text.substring(h.start, h.end),
        style: TextStyle(
          color: h.topic.color,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: h.topic.color.withValues(alpha: 0.6),
          decorationThickness: 2,
        ),
      ));
      i = h.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = KeywordController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _dismissed = {};
  List<Topic> _typed = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTyping);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTyping() {
    final found = KeywordDetector.instance.topicsIn(_input.text).where((t) => !_dismissed.contains(t.id)).toList();
    final changed = found.map((t) => t.id).join(',') != _typed.map((t) => t.id).join(',');
    if (changed) {
      if (found.length > _typed.length) HapticFeedback.selectionClick();
      setState(() => _typed = found);
    } else {
      setState(() {});
    }
  }

  Set<String> get _activeTopics => _typed.map((t) => t.id).toSet();

  bool get _danger => _activeTopics.intersection({'abuse', 'trafficking'}).isNotEmpty;

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _generating) return;
    final fil = AppScope.read(context).isFil;
    final topics = {...KeywordDetector.instance.topicsIn(text).map((t) => t.id), ..._activeTopics};
    HapticFeedback.lightImpact();
    final user = ChatMessage(fromUser: true, text: text, topics: topics);
    final kb = KnowledgeBase.instance.search(text, topics: topics, k: 3);
    final reply = ChatMessage(fromUser: false, text: '', topics: topics, sources: kb.map((e) => e.id).toList(), streaming: true);
    setState(() {
      _messages.addAll([user, reply]);
      _input.clear();
      _typed = [];
      _dismissed.clear();
      _generating = true;
    });
    _focus.unfocus();

    final ai = AiService.instance;
    try {
      if (ai.ready) {
        final last = _lastExchange();
        await for (final tok in ai.ask(system: systemPrompt(fil: fil), prompt: buildPrompt(question: text, context: kb, fil: fil, lastExchange: last))) {
          reply.text.value = cleanModelText(reply.text.value + tok);
        }
        if (reply.text.value.trim().isEmpty) reply.text.value = extractiveAnswer(kb, fil: fil);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        reply.text.value = extractiveAnswer(kb, fil: fil);
      }
    } catch (e) {
      reply.text.value = extractiveAnswer(kb, fil: fil);
    } finally {
      reply.streaming = false;
      if (mounted) setState(() => _generating = false);
    }
  }

  String? _lastExchange() {
    if (_messages.length < 4) return null;
    final q = _messages[_messages.length - 4];
    final a = _messages[_messages.length - 3];
    final ans = a.text.value;
    return 'Worker: ${q.text.value}\nKontrata: ${ans.length > 300 ? '${ans.substring(0, 300)}…' : ans}';
  }

  Future<void> _voice() async {
    final text = await showVoiceSheet(context);
    if (text == null || text.isEmpty || !mounted) return;
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  List<ChatMessage> get _visible {
    if (_activeTopics.isEmpty) return _messages;
    return _messages.where((m) => m.topics.intersection(_activeTopics).isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtering = _activeTopics.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const KLogo(size: 32),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kontrata'),
            const AiStatusPill(),
          ]),
        ]),
        toolbarHeight: 66,
        actions: [
          IconButton(
            tooltip: tr(context, 'My saved cases', 'Mga naitalang kaso'),
            onPressed: () => openPage(context, const CasesScreen()),
            icon: const Icon(Icons.folder_shared_rounded),
          ),
          IconButton(
            tooltip: tr(context, 'Settings', 'Settings'),
            onPressed: () => openPage(context, const SettingsScreen()),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: tr(context, 'Quick exit', 'Mabilis na labas'),
            onPressed: () {
              HapticFeedback.heavyImpact();
              SystemNavigator.pop();
            },
            icon: Icon(Icons.logout_rounded, color: KTokens.of(context).danger),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.d(context, 300),
              child: _messages.isEmpty && !filtering
                  ? _Welcome(key: const ValueKey('welcome'), onAsk: _send)
                  : _MessageList(
                      key: ValueKey('list-$filtering'),
                      messages: _visible,
                      filterTopics: _typed,
                      controller: _scroll,
                    ),
            ),
          ),
          _FilterBar(
            topics: _typed,
            onRemove: (t) => setState(() {
              _dismissed.add(t.id);
              _typed = _typed.where((x) => x.id != t.id).toList();
            }),
          ),
          if (_danger) const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 8), child: EmergencyBanner()),
          _QuickActions(topics: _activeTopics),
          _Composer(
            controller: _input,
            focus: _focus,
            generating: _generating,
            onSend: () => _send(),
            onStop: AiService.instance.stop,
            onMic: _voice,
          ),
        ]),
      ),
      backgroundColor: cs.surfaceContainerLowest,
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({super.key, required this.onAsk});
  final void Function(String) onAsk;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final d = Motion.d(context, 420);
    final suggestions = [
      tr(context, 'My contract was changed when I arrived', 'Pinalitan ang kontrata ko pagdating ko'),
      tr(context, 'What should my minimum salary be?', 'Magkano dapat ang minimum na sahod ko?'),
      tr(context, 'My employer took my passport', 'Kinuha ng employer ang passport ko'),
      tr(context, 'Is it too late to file a complaint?', 'Huli na ba para magsampa ng reklamo?'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: t.hero, borderRadius: BorderRadius.circular(26)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'Kumusta, kabayan.', 'Kumusta, kabayan.'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              tr(context, 'Ask me anything about your contract and rights. I answer from Philippine law, right here on your phone.',
                  'Itanong mo ang kahit ano tungkol sa kontrata at karapatan mo. Sasagot ako batay sa batas ng Pilipinas, dito mismo sa phone mo.'),
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: KColors.lPrimary, minimumSize: const Size(0, 50)),
              onPressed: () => openPage(context, const ScanFlowScreen()),
              icon: const Icon(Icons.document_scanner_rounded),
              label: Text(tr(context, 'Compare my contracts', 'Ikumpara ang kontrata ko')),
            ),
          ]),
        ).animate().fadeIn(duration: d).slideY(begin: 0.08, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.12,
          children: [
            ActionTile(
              icon: Icons.person_search_rounded,
              color: const Color(0xFFF97316),
              title: tr(context, 'Check my recruiter', 'I-check ang recruiter'),
              subtitle: tr(context, 'Spot illegal recruitment', 'Alamin kung illegal'),
              onTap: () => openPage(context, const RecruiterCheckScreen()),
            ),
            ActionTile(
              icon: Icons.route_rounded,
              color: t.success,
              title: tr(context, 'My options', 'Mga puwede kong gawin'),
              subtitle: tr(context, 'From quiet to formal', 'Mula tahimik hanggang pormal'),
              onTap: () => openPage(context, const LadderScreen()),
            ),
            ActionTile(
              icon: Icons.menu_book_rounded,
              color: cs.primary,
              title: tr(context, 'Know your rights', 'Alamin ang karapatan'),
              subtitle: tr(context, 'Laws, explained simply', 'Batas, sa simpleng salita'),
              onTap: () => openPage(context, const RightsScreen()),
            ),
            ActionTile(
              icon: Icons.support_agent_rounded,
              color: t.danger,
              title: tr(context, 'Get help now', 'Humingi ng tulong'),
              subtitle: '1348 · 1343',
              onTap: () => openPage(context, const LadderScreen(scrollToHotlines: true)),
            ),
          ].animate(interval: 70.ms).fadeIn(duration: d).scaleXY(begin: 0.94, curve: Curves.easeOutCubic),
        ),
        SectionLabel(tr(context, 'Try asking', 'Subukang itanong')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in suggestions)
            ActionChip(
              label: Text(s),
              onPressed: () => onAsk(s),
              avatar: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: cs.primary),
            ),
        ].animate(interval: 60.ms).fadeIn(duration: d).slideX(begin: 0.1)),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.tips_and_updates_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr(context, 'Tip: words like "sahod" or "passport" turn into filters as you type.',
                  'Tip: ang mga salitang tulad ng "sahod" o "passport" ay nagiging filter habang nagta-type ka.'),
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({super.key, required this.messages, required this.filterTopics, required this.controller});
  final List<ChatMessage> messages;
  final List<Topic> filterTopics;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final fil = AppScope.of(context).isFil;
    final filtering = filterTopics.isNotEmpty;
    final related = filtering
        ? KnowledgeBase.instance.search(filterTopics.map((t) => t.en).join(' '), topics: filterTopics.map((t) => t.id).toSet(), k: 2)
        : const <KbEntry>[];
    final items = <Widget>[
      for (final m in messages) _Bubble(key: ValueKey(m.id), message: m),
      if (filtering && messages.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            tr(context, 'No earlier messages on this. Your question will focus on it.', 'Wala pang naunang mensahe tungkol dito. Dito tututok ang tanong mo.'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      if (filtering)
        for (final e in related)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _KbPreview(entry: e, fil: fil),
          ),
    ];
    return ListView(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: items.reversed.toList(),
    );
  }
}

class _KbPreview extends StatelessWidget {
  const _KbPreview({required this.entry, required this.fil});
  final KbEntry entry;
  final bool fil;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      padding: const EdgeInsets.all(14),
      color: cs.secondaryContainer.withValues(alpha: 0.5),
      onTap: () => showKbSheet(context, entry),
      child: Row(children: [
        Icon(Icons.menu_book_rounded, color: cs.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title(fil), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(entry.sourceLabel, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ]),
    ).animate().fadeIn(duration: Motion.d(context, 280)).slideY(begin: 0.15);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = KTokens.of(context);
    final fil = AppScope.of(context).isFil;
    final user = message.fromUser;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: user ? t.userBubble : null,
        color: user ? null : cs.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(user ? 22 : 6),
          bottomRight: Radius.circular(user ? 6 : 22),
        ),
        border: user ? null : Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder<String>(
          valueListenable: message.text,
          builder: (context, text, _) {
            if (text.isEmpty && message.streaming) return const _TypingDots();
            return SelectableText(
              text,
              style: TextStyle(color: user ? Colors.white : cs.onSurface, fontSize: 15.5, height: 1.45),
            );
          },
        ),
        if (!user && message.sources.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in message.sources.take(3))
              if (KnowledgeBase.instance.byId(id) case final e?)
                Pressable(
                  onTap: () => showKbSheet(context, e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gavel_rounded, size: 12, color: cs.primary),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(e.sourceLabel, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.primary)),
                      ),
                    ]),
                  ),
                ),
          ]),
          const SizedBox(height: 6),
          Text(
            AiService.instance.ready ? tr(context, 'Answered offline by on-device AI', 'Sinagot offline ng AI sa phone') : tr(context, 'From the built-in legal guide', 'Mula sa built-in na legal guide'),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
        if (user && message.topics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final id in message.topics.take(4))
              if (topicById(id) case final tp?)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                  child: Text('#${tp.label(fil).toLowerCase()}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
          ]),
        ],
      ]),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[const KLogo(size: 26), const SizedBox(width: 6)],
          Flexible(child: bubble),
        ],
      ),
    );
    if (message.animated || Motion.reduced(context)) return row;
    message.animated = true;
    return row
        .animate()
        .fadeIn(duration: Motion.d(context, 260))
        .slideY(begin: 0.25, curve: Curves.easeOutCubic, duration: Motion.d(context, 320))
        .scaleXY(begin: 0.96, alignment: user ? Alignment.bottomRight : Alignment.bottomLeft);
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 20,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).moveY(begin: 0, end: -5, delay: (i * 140).ms, duration: 380.ms, curve: Curves.easeInOut).then().moveY(begin: -5, end: 0, duration: 380.ms),
      ]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.topics, required this.onRemove});
  final List<Topic> topics;
  final void Function(Topic) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: Motion.d(context, 260),
      curve: Curves.easeOutCubic,
      child: topics.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(children: [
                Icon(Icons.filter_alt_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(tr(context, 'Filter', 'Filter'), style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final t in topics)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TopicChip(key: ValueKey(t.id), topic: t, onClose: () => onRemove(t))
                              .animate()
                              .fadeIn(duration: Motion.d(context, 200))
                              .scaleXY(begin: 0.6, curve: Curves.easeOutBack, duration: Motion.d(context, 320)),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.topics});
  final Set<String> topics;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Widget)>[];
    if (topics.intersection({'contract', 'salary', 'hours', 'rest_day', 'leave', 'food_lodging'}).isNotEmpty) {
      actions.add((Icons.document_scanner_rounded, tr(context, 'Compare contracts', 'Ikumpara ang kontrata'), const ScanFlowScreen()));
    }
    if (topics.intersection({'recruiter', 'fees', 'agency', 'trafficking', 'passport'}).isNotEmpty) {
      actions.add((Icons.person_search_rounded, tr(context, 'Check recruiter', 'I-check ang recruiter'), const RecruiterCheckScreen()));
    }
    if (topics.intersection({'complaint', 'evidence', 'deadline', 'help', 'repatriation', 'abuse'}).isNotEmpty) {
      actions.add((Icons.route_rounded, tr(context, 'My options', 'Mga hakbang ko'), const LadderScreen()));
    }
    return AnimatedSize(
      duration: Motion.d(context, 260),
      child: actions.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                children: [
                  for (final a in actions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () => openPage(context, a.$3),
                        icon: Icon(a.$1, size: 18),
                        label: Text(a.$2),
                      ).animate().fadeIn(duration: Motion.d(context, 220)).slideX(begin: 0.2),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.generating, required this.onSend, required this.onStop, required this.onMic});
  final TextEditingController controller;
  final FocusNode focus;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasText = controller.text.trim().isNotEmpty;
    final mode = generating ? 'stop' : (hasText ? 'send' : 'mic');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton.filledTonal(
          tooltip: tr(context, 'Scan a contract', 'Mag-scan ng kontrata'),
          onPressed: () => openPage(context, const ScanFlowScreen()),
          icon: const Icon(Icons.document_scanner_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: tr(context, 'Type or talk… e.g. "sahod"', 'Mag-type o magsalita… hal. "sahod"'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: cs.outline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: cs.outline)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: cs.primary, width: 1.6)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Pressable(
          scale: 0.9,
          onTap: switch (mode) { 'stop' => onStop, 'send' => onSend, _ => onMic },
          child: AnimatedContainer(
            duration: Motion.d(context, 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: mode == 'stop' ? null : KTokens.of(context).hero,
              color: mode == 'stop' ? KTokens.of(context).danger : null,
              shape: BoxShape.circle,
              boxShadow: Motion.reduced(context) ? null : [BoxShadow(color: KTokens.of(context).glow, blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: AnimatedSwitcher(
              duration: Motion.d(context, 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: c)),
              child: Icon(
                switch (mode) { 'stop' => Icons.stop_rounded, 'send' => Icons.arrow_upward_rounded, _ => Icons.mic_rounded },
                key: ValueKey(mode),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Shows one knowledge-base entry with its source.
Future<void> showKbSheet(BuildContext context, KbEntry e) {
  final fil = AppScope.read(context).isFil;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      final cs = Theme.of(c).colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (c, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            Text(e.title(fil), style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(e.body(fil), style: Theme.of(c).textTheme.bodyLarge),
            if (fil) ...[
              const SizedBox(height: 14),
              Text(e.bodyEn, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5, height: 1.4)),
            ],
            const SizedBox(height: 16),
            KCard(
              padding: const EdgeInsets.all(12),
              color: cs.primaryContainer.withValues(alpha: 0.5),
              child: Row(children: [
                Icon(Icons.gavel_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(e.sourceLabel, style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary))),
              ]),
            ),
            const SizedBox(height: 6),
            Text(e.sourceUrl, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Text(KnowledgeBase.instance.disclaimer(fil), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    },
  );
}
