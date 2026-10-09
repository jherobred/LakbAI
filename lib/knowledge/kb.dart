import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class KbEntry {
  KbEntry.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        kind = j['kind'] as String,
        topics = (j['topics'] as List).cast<String>(),
        titleEn = j['title_en'] as String,
        titleFil = j['title_fil'] as String,
        bodyEn = j['body_en'] as String,
        bodyFil = j['body_fil'] as String,
        sourceLabel = (j['source'] as Map)['label'] as String,
        sourceUrl = (j['source'] as Map)['url'] as String;

  final String id;
  final String kind;
  final List<String> topics;
  final String titleEn;
  final String titleFil;
  final String bodyEn;
  final String bodyFil;
  final String sourceLabel;
  final String sourceUrl;

  String title(bool fil) => fil ? titleFil : titleEn;
  String body(bool fil) => fil ? bodyFil : bodyEn;
}

/// Offline legal knowledge base with a small BM25 search.
class KnowledgeBase {
  KnowledgeBase._(this.entries, this.disclaimerEn, this.disclaimerFil, this.version) {
    for (final e in entries) {
      final toks = _tokens('${e.titleEn} ${e.titleFil} ${e.bodyEn} ${e.bodyFil} ${e.topics.join(' ')}');
      _docTokens[e.id] = toks;
      for (final t in toks.toSet()) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avgLen = entries.isEmpty ? 1 : _docTokens.values.map((l) => l.length).reduce((a, b) => a + b) / entries.length;
  }

  static late KnowledgeBase instance;

  final List<KbEntry> entries;
  final String disclaimerEn;
  final String disclaimerFil;
  final String version;
  final Map<String, List<String>> _docTokens = {};
  final Map<String, int> _df = {};
  late final double _avgLen;

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/kb/knowledge.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    instance = KnowledgeBase._(
      (j['entries'] as List).map((e) => KbEntry.fromJson(e as Map<String, dynamic>)).toList(),
      j['disclaimer_en'] as String,
      j['disclaimer_fil'] as String,
      j['version'] as String,
    );
  }

  KbEntry? byId(String id) => entries.where((e) => e.id == id).firstOrNull;

  String disclaimer(bool fil) => fil ? disclaimerFil : disclaimerEn;

  static const _stop = {
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'is', 'it', 'for', 'on', 'my', 'i', 'me', 'you', 'what',
    'can', 'do', 'be', 'are', 'was', 'ang', 'ng', 'sa', 'na', 'ko', 'mo', 'ba', 'ay', 'at', 'si', 'ni', 'nga',
    'po', 'yung', 'yun', 'ano', 'paano', 'kung', 'may', 'ako', 'ka', 'lang', 'din', 'rin', 'pa', 'naman'
  };

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.length > 1 && !_stop.contains(t))
      .toList();

  /// Best entries for [query], boosted for entries tagged with [topics].
  List<KbEntry> search(String query, {Set<String> topics = const {}, int k = 3}) {
    final q = _tokens(query);
    final n = entries.length;
    final scored = <MapEntry<KbEntry, double>>[];
    for (final e in entries) {
      final doc = _docTokens[e.id]!;
      var s = 0.0;
      for (final term in q.toSet()) {
        final tf = doc.where((d) => d == term || (term.length > 4 && d.startsWith(term))).length;
        if (tf == 0) continue;
        final df = _df[term] ?? 1;
        final idf = log(1 + (n - df + 0.5) / (df + 0.5));
        s += idf * (tf * 2.2) / (tf + 1.2 * (0.25 + 0.75 * doc.length / _avgLen));
      }
      final overlap = e.topics.where(topics.contains).length;
      s += overlap * 2.5;
      if (s > 0) scored.add(MapEntry(e, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(k).map((e) => e.key).toList();
  }

  List<KbEntry> byTopic(String topic) => entries.where((e) => e.topics.contains(topic)).toList();
}
