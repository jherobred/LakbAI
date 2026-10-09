import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../ai/ai_service.dart';
import '../ai/prompts.dart';
import '../core/app_state.dart';
import '../knowledge/kb.dart';
import '../knowledge/topics.dart';
import '../theme.dart';
import 'ai_widgets.dart';
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

  /// Whether the on-device model wrote this reply (false: the built-in guide did).
  bool byAi = false;
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
  late final _voice = VoiceCapture(onAutoStop: _finishVoice);

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTyping);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _voice.dispose();
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
    final fil = looksFilipino(text, fallback: AppScope.read(context).isFil);
    final topics = {...KeywordDetector.instance.topicsIn(text).map((t) => t.id), ..._activeTopics};
    HapticFeedback.lightImpact();
    final user = ChatMessage(fromUser: true, text: text, topics: topics);
    // Two entries keep the prompt short, which is what makes the first word come fast.
    final kb = KnowledgeBase.instance.search(text, topics: topics, k: 2);
    final reply = ChatMessage(fromUser: false, text: '', topics: topics, sources: kb.map((e) => e.id).toList(), streaming: true);
    setState(() {
      _messages.addAll([user, reply]);
      _input.clear();
      _typed = [];
      _dismissed.clear();
      _generating = true;
    });
    _focus.unfocus();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: Motion.d(context, 300), curve: Curves.easeOutCubic);

    final ai = AiService.instance;
    try {
      if (ai.ready) {
        reply.byAi = true;
        final last = _lastExchange();
        // Keep the raw stream and show a cleaned copy, so line breaks between tokens survive.
        final raw = StringBuffer();
        await for (final tok in ai.ask(
          system: systemPrompt(fil: fil),
          prompt: buildPrompt(question: text, context: kb, fil: fil, lastExchange: last),
          maxOutputTokens: 260,
        )) {
          raw.write(tok);
          reply.text.value = cleanModelText(raw.toString());
        }
        if (reply.text.value.trim().isEmpty) {
          reply.byAi = false;
          reply.text.value = extractiveAnswer(kb, fil: fil);
        }
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        reply.text.value = extractiveAnswer(kb, fil: fil);
      }
    } catch (e) {
      reply.byAi = false;
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
    return 'Worker: ${q.text.value}\nLakbAI: ${ans.length > 240 ? '${ans.substring(0, 240)}…' : ans}';
  }

  Future<void> _startVoice() async {
    if (!AiService.instance.voiceReady) {
      // Voice is still being set up (or needs its one-time download): use the sheet that explains it.
      final text = await showVoiceSheet(context);
      if (text != null && text.isNotEmpty && mounted) _send(text);
      return;
    }
    _focus.unfocus();
    final ok = await _voice.start(permissionMessage: tr(context, 'Allow the microphone in Settings to talk.', 'Payagan ang mikropono sa Settings para makapagsalita.'));
    if (!ok && mounted) _snack(_voice.error ?? '');
  }

  Future<void> _finishVoice() async {
    if (_voice.phase != VoicePhase.recording) return;
    final text = await _voice.finish(AppScope.read(context).voiceLang);
    if (!mounted) return;
    if (_voice.phase == VoicePhase.error) {
      _snack(tr(context, 'Could not turn that into text. Try again.', 'Hindi ito nagawang text. Subukan ulit.'));
      _voice.cancel();
    } else if (text.isEmpty) {
      _snack(tr(context, "I didn't catch that. Try again a little closer.", 'Hindi ko narinig. Subukan ulit nang mas malapit.'));
    } else {
      _send(text);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  List<ChatMessage> get _visible {
    if (_activeTopics.isEmpty) return _messages;
    return _messages.where((m) => m.topics.intersection(_activeTopics).isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtering = _activeTopics.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const KLogo(size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('LakbAI'),
            const AiStatusPill(),
          ]),
        ]),
        toolbarHeight: 66,
        actions: [
          IconButton(
            tooltip: tr(context, 'My saved cases', 'Mga naitalang kaso'),
            onPressed: () => openPage(context, const CasesScreen()),
            icon: const Icon(Icons.folder_outlined),
          ),
          IconButton(
            tooltip: tr(context, 'Settings', 'Settings'),
            onPressed: () => openPage(context, const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
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
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
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
            voice: _voice,
            generating: _generating,
            onSend: () => _send(),
            onStop: AiService.instance.stop,
            onMic: _startVoice,
            onVoiceDone: _finishVoice,
          ),
        ]),
      ),
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
    final suggestions = <(IconData, Color, String)>[
      (Icons.description_outlined, const Color(0xFF4285F4), tr(context, 'My contract was changed when I arrived', 'Pinalitan ang kontrata ko pagdating ko')),
      (Icons.payments_outlined, const Color(0xFF0F9D58), tr(context, 'What should my minimum salary be?', 'Magkano dapat ang minimum na sahod ko?')),
      (Icons.badge_outlined, const Color(0xFF9B72CB), tr(context, 'My employer took my passport', 'Kinuha ng employer ang passport ko')),
      (Icons.event_outlined, const Color(0xFFE37400), tr(context, 'Is it too late to file a complaint?', 'Huli na ba para magsampa ng reklamo?')),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        GradientGreeting(
          tr(context, 'Kumusta, kabayan.', 'Kumusta, kabayan.'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 32),
        ).animate().fadeIn(duration: d).slideY(begin: 0.15, curve: Curves.easeOutCubic),
        const SizedBox(height: 4),
        Text(
          tr(context, 'How can I help with your contract today?', 'Paano kita matutulungan sa kontrata mo ngayon?'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.75), fontSize: 24, height: 1.25),
        ).animate().fadeIn(duration: d, delay: 80.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),
        const SizedBox(height: 22),
        // Main tool, with an illustration of what it does.
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(gradient: t.hero, borderRadius: BorderRadius.circular(28)),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => openPage(context, const ScanFlowScreen()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(context, 'Compare my contracts', 'Ikumpara ang kontrata ko'),
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        tr(context, 'Scan the verified contract and the new one. I will find every change.', 'I-scan ang verified na kontrata at ang bago. Hahanapin ko ang bawat pagbabago.'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.document_scanner_outlined, size: 18, color: KColors.lPrimary),
                          const SizedBox(width: 6),
                          Text(tr(context, 'Start scan', 'Mag-scan'), style: const TextStyle(color: KColors.lPrimary, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                  const ContractArt(size: 104),
                ]),
              ),
            ),
          ),
        ).animate().fadeIn(duration: d, delay: 140.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
        const SizedBox(height: 18),
        Text(tr(context, 'Try asking', 'Subukang itanong'), style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (icon, color, text) = suggestions[i];
              return SizedBox(
                width: 168,
                child: Material(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onAsk(text),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35), maxLines: 4, overflow: TextOverflow.ellipsis)),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                            child: Icon(icon, size: 18, color: color),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: d, delay: (200 + i * 60).ms).slideX(begin: 0.15, curve: Curves.easeOutCubic);
            },
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            ActionTile(
              icon: Icons.person_search_outlined,
              color: const Color(0xFFE37400),
              title: tr(context, 'Check my recruiter', 'I-check ang recruiter'),
              subtitle: tr(context, 'Spot illegal recruitment', 'Alamin kung illegal'),
              onTap: () => openPage(context, const RecruiterCheckScreen()),
            ),
            ActionTile(
              icon: Icons.route_outlined,
              color: t.success,
              title: tr(context, 'My options', 'Mga puwede kong gawin'),
              subtitle: tr(context, 'From quiet to formal', 'Mula tahimik hanggang pormal'),
              onTap: () => openPage(context, const LadderScreen()),
            ),
            ActionTile(
              icon: Icons.menu_book_outlined,
              color: cs.primary,
              title: tr(context, 'Know your rights', 'Alamin ang karapatan'),
              subtitle: tr(context, 'Laws, explained simply', 'Batas, sa simpleng salita'),
              onTap: () => openPage(context, const RightsScreen()),
            ),
            ActionTile(
              icon: Icons.support_agent_outlined,
              color: t.danger,
              title: tr(context, 'Get help now', 'Humingi ng tulong'),
              subtitle: '1348 · 1343',
              onTap: () => openPage(context, const LadderScreen(scrollToHotlines: true)),
            ),
          ].animate(interval: 60.ms, delay: 300.ms).fadeIn(duration: d).scaleXY(begin: 0.96, curve: Curves.easeOutCubic),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr(context, 'Everything stays on this phone. Works in airplane mode.', 'Nasa phone mo lang ang lahat. Gumagana kahit naka-airplane mode.'),
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
      for (final m in messages) m.fromUser ? _UserBubble(key: ValueKey(m.id), message: m) : _AiReply(key: ValueKey(m.id), message: m),
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
      onTap: () => showKbSheet(context, entry),
      child: Row(children: [
        Icon(Icons.menu_book_outlined, color: cs.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title(fil), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(entry.sourceLabel, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ]),
    ).animate().fadeIn(duration: Motion.d(context, 280)).slideY(begin: 0.15);
  }
}

/// Entrance motion shared by both sides of the conversation; plays once per message.
Widget _enter(BuildContext context, ChatMessage m, Widget child, {required bool user}) {
  if (m.animated || Motion.reduced(context)) return child;
  m.animated = true;
  return child
      .animate()
      .fadeIn(duration: Motion.d(context, 260))
      .slideY(begin: 0.2, curve: Curves.easeOutCubic, duration: Motion.d(context, 340))
      .scaleXY(begin: 0.97, alignment: user ? Alignment.bottomRight : Alignment.bottomLeft, curve: Curves.easeOutCubic);
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fil = AppScope.of(context).isFil;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        color: KTokens.of(context).userBubble,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        SelectableText(message.text.value, style: TextStyle(color: cs.onSurface, fontSize: 15.5, height: 1.45)),
        if (message.topics.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final id in message.topics.take(4))
              if (topicById(id) case final tp?)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: tp.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                  child: Text('#${tp.label(fil).toLowerCase()}', style: TextStyle(color: tp.color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
          ]),
        ],
      ]),
    );
    return _enter(
      context,
      message,
      Padding(
        padding: const EdgeInsets.fromLTRB(48, 8, 14, 8),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      ),
      user: true,
    );
  }
}

/// The model's answer: no bubble, full width, with the spark beside it, as in Gemini.
class _AiReply extends StatelessWidget {
  const _AiReply({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fil = AppScope.of(context).isFil;
    final sources = [for (final id in message.sources.take(3)) ?KnowledgeBase.instance.byId(id)];
    final body = ValueListenableBuilder<String>(
      valueListenable: message.text,
      builder: (context, text, _) {
        final waiting = text.isEmpty && message.streaming;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AiSpark(size: 22, busy: message.streaming),
            const SizedBox(width: 10),
            Text(
              waiting ? tr(context, 'Thinking…', 'Nag-iisip…') : answeredBy(context, message.byAi),
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: Motion.d(context, 200),
            alignment: Alignment.topLeft,
            curve: Curves.easeOutCubic,
            child: waiting ? const ThinkingShimmer() : SelectionArea(child: MarkdownText(text)),
          ),
          if (!message.streaming && sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _SourceCard(entry: sources[i], fil: fil)
                    .animate()
                    .fadeIn(duration: Motion.d(context, 260), delay: (i * 70).ms)
                    .slideX(begin: 0.1, curve: Curves.easeOutCubic),
              ),
            ),
          ],
          if (!message.streaming && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr(context, 'Copy', 'Kopyahin'),
                  icon: Icon(Icons.content_copy_rounded, size: 18, color: cs.onSurfaceVariant),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text.replaceAll('**', '')));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Copied', 'Nakopya'))));
                  },
                ),
              ]),
            ),
        ]);
      },
    );
    return _enter(context, message, Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), child: body), user: false);
  }
}

/// A cited law, shown as a small card with the topic's icon, like a search result.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.entry, required this.fil});
  final KbEntry entry;
  final bool fil;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topic = entry.topics.map(topicById).whereType<Topic>().firstOrNull;
    final color = topic?.color ?? cs.primary;
    return SizedBox(
      width: 230,
      child: Material(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showKbSheet(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(topic?.icon ?? Icons.gavel_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.title(fil), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
                  const SizedBox(height: 2),
                  Text(entry.sourceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ),
      ),
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

/// Gemini-style input: one rounded surface holding the text field and its
/// tools. While listening it turns into a live sound wave.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.voice,
    required this.generating,
    required this.onSend,
    required this.onStop,
    required this.onMic,
    required this.onVoiceDone,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final VoiceCapture voice;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onMic;
  final VoidCallback onVoiceDone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dur = Motion.d(context, 260);
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final listening = voice.phase == VoicePhase.recording;
        final writing = voice.phase == VoicePhase.transcribing;
        final hasText = controller.text.trim().isNotEmpty;
        final Widget content;
        if (listening || writing) {
          content = Padding(
            key: const ValueKey('voice'),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(children: [
              IconButton(
                tooltip: tr(context, 'Cancel', 'Kanselahin'),
                onPressed: writing ? null : voice.cancel,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: writing
                    ? Row(children: [
                        const AiSpark(size: 18, busy: true),
                        const SizedBox(width: 10),
                        Flexible(child: Text(tr(context, 'Writing down what you said…', 'Isinusulat ang sinabi mo…'), style: TextStyle(color: cs.onSurfaceVariant))),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        VoiceWave(levels: voice.levels, active: true, height: 34, barWidth: 3),
                        const SizedBox(height: 2),
                        Text(
                          tr(context, 'Listening… stops when you pause', 'Nakikinig… hihinto pag tumigil ka'),
                          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                      ]),
              ),
              const SizedBox(width: 4),
              if (!writing) const VoiceLangToggle(),
              const SizedBox(width: 6),
              _RoundButton(
                icon: Icons.arrow_upward_rounded,
                filled: true,
                tooltip: tr(context, 'Done', 'Tapos na'),
                onTap: writing ? null : onVoiceDone,
              ),
            ]),
          );
        } else {
          content = Column(key: const ValueKey('text'), mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: tr(context, 'Ask LakbAI', 'Magtanong kay LakbAI'),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(children: [
                _RoundButton(
                  icon: Icons.add_rounded,
                  tooltip: tr(context, 'Tools', 'Mga tool'),
                  onTap: () => _showTools(context),
                ),
                const SizedBox(width: 4),
                _ToolPill(
                  icon: Icons.document_scanner_outlined,
                  label: tr(context, 'Compare', 'Ikumpara'),
                  onTap: () => openPage(context, const ScanFlowScreen()),
                ),
                const Spacer(),
                if (!generating)
                  _RoundButton(icon: Icons.mic_none_rounded, tooltip: tr(context, 'Speak', 'Magsalita'), onTap: onMic),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: Motion.d(context, 200),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: generating
                      ? _RoundButton(key: const ValueKey('stop'), icon: Icons.stop_rounded, filled: true, tooltip: tr(context, 'Stop', 'Ihinto'), onTap: onStop)
                      : hasText
                          ? _RoundButton(key: const ValueKey('send'), icon: Icons.arrow_upward_rounded, filled: true, tooltip: tr(context, 'Send', 'Ipadala'), onTap: onSend)
                          : const SizedBox(key: ValueKey('none'), width: 0, height: 44),
                ),
              ]),
            ),
          ]);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: focus.hasFocus || listening ? cs.primary.withValues(alpha: 0.5) : Colors.transparent, width: 1.2),
              boxShadow: focus.hasFocus || listening ? [BoxShadow(color: KTokens.of(context).glow, blurRadius: 24, offset: const Offset(0, 6))] : null,
            ),
            child: AnimatedSize(
              duration: dur,
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: dur,
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, this.onTap, this.filled = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? (onTap == null ? cs.onSurface.withValues(alpha: 0.12) : cs.primary) : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox.square(dimension: 44, child: Icon(icon, size: 24, color: filled ? cs.onPrimary : cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  const _ToolPill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// The "+" menu: every tool in the app, one tap from the chat.
void _showTools(BuildContext context) {
  final t = KTokens.of(context);
  final cs = Theme.of(context).colorScheme;
  final tools = <(IconData, Color, String, String, Widget)>[
    (Icons.document_scanner_outlined, cs.primary, tr(context, 'Compare contracts', 'Ikumpara ang kontrata'), tr(context, 'Scan both and see every change', 'I-scan pareho at tingnan ang bawat pagbabago'), const ScanFlowScreen()),
    (Icons.person_search_outlined, const Color(0xFFE37400), tr(context, 'Check my recruiter', 'I-check ang recruiter'), tr(context, 'Warning signs of illegal recruitment', 'Mga senyales ng illegal recruitment'), const RecruiterCheckScreen()),
    (Icons.route_outlined, t.success, tr(context, 'My options', 'Mga puwede kong gawin'), tr(context, 'Six steps, quietest first', 'Anim na hakbang, pinakatahimik muna'), const LadderScreen()),
    (Icons.menu_book_outlined, KColors.purple, tr(context, 'Know your rights', 'Alamin ang karapatan'), tr(context, 'Laws in plain words', 'Mga batas sa simpleng salita'), const RightsScreen()),
    (Icons.folder_outlined, cs.onSurfaceVariant, tr(context, 'My saved cases', 'Mga naitalang kaso'), tr(context, 'Evidence and reports', 'Ebidensya at mga report'), const CasesScreen()),
  ];
  showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (icon, color, title, sub, page) in tools)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(sub),
              onTap: () {
                Navigator.pop(c);
                openPage(context, page);
              },
            ),
        ]),
      ),
    ),
  );
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
