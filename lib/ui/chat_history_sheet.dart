import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../chat/chat_history.dart';
import '../core/app_state.dart';
import '../theme.dart';

/// What the person picked in the history sheet.
class HistoryChoice {
  const HistoryChoice.open(Conversation this.conversation) : newChat = false;
  const HistoryChoice.newChat()
      : conversation = null,
        newChat = true;
  final Conversation? conversation;
  final bool newChat;
}

/// Past chats with the on-device AI, newest first. Returns null when closed
/// without a choice; deletions made inside apply right away.
Future<HistoryChoice?> showChatHistory(BuildContext context, {String? currentId}) {
  return showModalBottomSheet<HistoryChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HistorySheet(currentId: currentId),
  );
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({this.currentId});
  final String? currentId;
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<Conversation>? _chats;

  @override
  void initState() {
    super.initState();
    ChatHistory.instance.list().then((c) {
      if (mounted) setState(() => _chats = List.of(c));
    });
  }

  Future<void> _delete(Conversation c) async {
    HapticFeedback.mediumImpact();
    setState(() => _chats!.remove(c));
    await ChatHistory.instance.delete(c.id);
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Delete all chats?', 'Burahin lahat ng chat?')),
        content: Text(tr(c, 'This removes every saved chat from this phone. It cannot be undone.', 'Mabubura ang lahat ng naitalang chat sa phone na ito. Hindi na ito maibabalik.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'Cancel', 'Kanselahin'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KTokens.of(c).danger),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(c, 'Delete', 'Burahin')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ChatHistory.instance.deleteAll();
    if (mounted) setState(() => _chats = []);
  }

  String _group(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return tr(context, 'Today', 'Ngayong araw');
    if (diff == 1) return tr(context, 'Yesterday', 'Kahapon');
    if (diff < 7) return tr(context, 'Previous 7 days', 'Nakaraang 7 araw');
    return tr(context, 'Older', 'Mas luma');
  }

  String _time(BuildContext context, DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return sameDay ? '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}' : '${months[t.month - 1]} ${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chats = _chats;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        final items = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
            child: Row(children: [
              Expanded(child: Text(tr(context, 'Chats', 'Mga chat'), style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => Navigator.pop(context, const HistoryChoice.newChat()),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(tr(context, 'New chat', 'Bagong chat')),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, 'Saved only on this phone. Never uploaded.', 'Nasa phone lang na ito. Hindi ina-upload.'),
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ),
            ]),
          ),
        ];

        if (chats == null) {
          items.add(const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
        } else if (chats.isEmpty) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
            child: Column(children: [
              Icon(Icons.forum_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(tr(context, 'No saved chats yet', 'Wala pang naitalang chat'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                tr(context, 'Your questions and answers will appear here after you ask something.', 'Lalabas dito ang mga tanong at sagot mo pagkatapos mong magtanong.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ]),
          ));
        } else {
          String? lastGroup;
          for (final (i, c) in chats.indexed) {
            final g = _group(context, c.updatedAt);
            if (g != lastGroup) {
              lastGroup = g;
              items.add(Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(g, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurfaceVariant)),
              ));
            }
            items.add(_ChatTile(
              key: ValueKey(c.id),
              chat: c,
              time: _time(context, c.updatedAt),
              current: c.id == widget.currentId,
              onOpen: () => Navigator.pop(context, HistoryChoice.open(c)),
              onDelete: () => _delete(c),
            ).animate().fadeIn(duration: Motion.d(context, 220), delay: (i.clamp(0, 8) * 30).ms).slideY(begin: 0.08, curve: Curves.easeOutCubic));
          }
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: KTokens.of(context).danger),
                onPressed: _deleteAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(tr(context, 'Delete all chats', 'Burahin lahat ng chat')),
              ),
            ),
          ));
        }
        return ListView(controller: scroll, padding: EdgeInsets.zero, children: items);
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({super.key, required this.chat, required this.time, required this.current, required this.onOpen, required this.onDelete});
  final Conversation chat;
  final String time;
  final bool current;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('d-${chat.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        color: KTokens.of(context).danger.withValues(alpha: 0.12),
        child: Icon(Icons.delete_outline_rounded, color: KTokens.of(context).danger),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: current ? cs.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
                  child: Icon(Icons.chat_bubble_outline_rounded, size: 19, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      chat.preview.isEmpty ? time : '$time · ${chat.preview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ]),
                ),
                if (chat.questionCount > 1)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(99)),
                    child: Text('${chat.questionCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  ),
                IconButton(
                  tooltip: tr(context, 'Delete chat', 'Burahin ang chat'),
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
