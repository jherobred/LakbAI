import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One message as it is kept on the phone.
class SavedMessage {
  const SavedMessage({required this.fromUser, required this.text, this.topics = const [], this.sources = const [], this.byAi = false});

  final bool fromUser;
  final String text;
  final List<String> topics;
  final List<String> sources;
  final bool byAi;

  Map<String, dynamic> toJson() => {'u': fromUser, 't': text, 'tp': topics, 's': sources, 'ai': byAi};

  factory SavedMessage.fromJson(Map<String, dynamic> j) => SavedMessage(
        fromUser: j['u'] as bool? ?? false,
        text: j['t'] as String? ?? '',
        topics: (j['tp'] as List? ?? const []).cast<String>(),
        sources: (j['s'] as List? ?? const []).cast<String>(),
        byAi: j['ai'] as bool? ?? false,
      );
}

/// One past chat with the on-device AI.
class Conversation {
  Conversation({required this.id, required this.updatedAt, required this.messages});

  final String id;
  DateTime updatedAt;
  List<SavedMessage> messages;

  /// The first question names the chat.
  String get title => messages.where((m) => m.fromUser).map((m) => m.text).firstOrNull ?? '';

  /// The latest answer, as a one-line preview.
  String get preview {
    final last = messages.where((m) => !m.fromUser).lastOrNull?.text ?? '';
    return last.replaceAll('**', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int get questionCount => messages.where((m) => m.fromUser).length;

  Map<String, dynamic> toJson() => {'id': id, 'at': updatedAt.toIso8601String(), 'm': messages.map((m) => m.toJson()).toList()};

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        updatedAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        messages: (j['m'] as List? ?? const []).map((m) => SavedMessage.fromJson(m as Map<String, dynamic>)).toList(),
      );
}

/// Past chats, kept only in this app's private folder on the phone. Nothing
/// here is uploaded; "Delete everything" and the per-chat delete remove it.
class ChatHistory {
  ChatHistory._();
  static final instance = ChatHistory._();

  /// Oldest chats beyond this are dropped so the file stays small.
  static const maxChats = 50;

  List<Conversation>? _cache;

  Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/chat_history.json');
    } catch (_) {
      // No private folder (for example the web preview): history lives in memory only.
      return null;
    }
  }

  /// Newest first.
  Future<List<Conversation>> list() async {
    if (_cache != null) return _cache!;
    final f = await _file();
    var chats = <Conversation>[];
    try {
      if (f != null && await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as List;
        chats = raw.map((c) => Conversation.fromJson(c as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // A damaged file should not break the chat; start a fresh history.
    }
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _cache = chats;
  }

  Future<void> _write() async {
    final f = await _file();
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(_cache!.map((c) => c.toJson()).toList()), flush: true);
    await tmp.rename(f.path);
  }

  /// Saves [c], replacing an older copy with the same id, and moves it to the top.
  Future<void> save(Conversation c) async {
    final chats = await list();
    chats
      ..removeWhere((x) => x.id == c.id)
      ..insert(0, c);
    if (chats.length > maxChats) chats.removeRange(maxChats, chats.length);
    await _write();
  }

  Future<void> delete(String id) async {
    (await list()).removeWhere((c) => c.id == id);
    await _write();
  }

  Future<void> deleteAll() async {
    _cache = [];
    final f = await _file();
    try {
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}
