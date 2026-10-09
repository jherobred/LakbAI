import '../knowledge/kb.dart';

/// Kept short on purpose: every token here is re-read by the small on-device
/// model before each reply, so a shorter prompt means a faster first word.
String systemPrompt({required bool fil}) => '''
You are Kontrata, a friendly offline helper for Overseas Filipino Workers (OFWs).
Answer in ${fil ? 'simple Filipino (Taglish is fine)' : 'simple English'}.
Format:
1. One short sentence that answers directly.
2. Up to 3 bullet points ("- ") with what to do or know. Use **bold** for key numbers.
3. A last line: "Source: <law>".
Use only facts from CONTEXT. Never invent laws, numbers or phone numbers. If CONTEXT does not cover it, say so and suggest calling 1348.
Never push the worker to confront the employer. If they are in danger, tell them to call 1343 or 1348 first.''';

/// Long entries slow the model down; the first sentences carry the facts.
String _clip(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf('. ');
  return end > max ~/ 2 ? cut.substring(0, end + 1) : '$cut…';
}

String buildContext(List<KbEntry> entries, {required bool fil}) {
  final b = StringBuffer('CONTEXT:\n');
  for (final e in entries) {
    b.writeln('- ${e.titleEn}: ${_clip(e.bodyEn, 320)} (Source: ${e.sourceLabel})');
  }
  return b.toString();
}

String buildPrompt({required String question, required List<KbEntry> context, required bool fil, String? lastExchange}) {
  final b = StringBuffer(buildContext(context, fil: fil));
  if (lastExchange != null && lastExchange.isNotEmpty) {
    b.writeln('\nEARLIER:\n$lastExchange');
  }
  b.writeln('\nQUESTION: $question');
  return b.toString();
}

/// Used when no model is installed yet, or the phone is too busy:
/// answer straight from the knowledge base so the app is never useless.
String extractiveAnswer(List<KbEntry> entries, {required bool fil}) {
  if (entries.isEmpty) {
    return fil
        ? 'Wala akong eksaktong sagot dito. Puwede kang tumawag sa **1348** (DMW/OWWA, 24/7) o lumapit sa Migrant Workers Office sa embahada.'
        : "I don't have an exact answer for that. You can call **1348** (DMW/OWWA, 24/7) or visit the Migrant Workers Office at the embassy.";
  }
  final b = StringBuffer();
  for (final e in entries.take(2)) {
    b.writeln('**${e.title(fil)}**');
    b.writeln(e.body(fil));
    b.writeln();
  }
  b.write('Source: ${entries.first.sourceLabel}');
  return b.toString().trim();
}

String explainChangesPrompt({required String diffSummary, required bool fil}) => '''
CONTEXT:
- Changing a DMW-verified contract to the worker's disadvantage without DMW approval is illegal (Labor Code Art. 34(i); RA 8042 Sec. 6).
- The Philippine agency stays jointly liable for money claims even if the contract was changed abroad (RA 8042 Sec. 10).
- Money claims can be filed within 3 years (Labor Code Art. 306).

CHANGES FOUND BETWEEN THE VERIFIED CONTRACT AND THE NEW ONE:
$diffSummary

Explain to the worker in ${fil ? 'simple Filipino' : 'simple English'}, in under 110 words, what these changes mean for them. Start with one plain sentence, then short "- " bullets. Be calm. Do not tell them to confront anyone. End by saying they can keep this evidence and decide later.''';

String statementPrompt({required String rawText, required bool fil}) => '''
Rewrite the worker's account below as a clear, first-person statement for an incident report, in ${fil ? 'Filipino' : 'English'}.
Keep every fact, date, name and number exactly as given. Do not add facts. Use short paragraphs in time order. No headings.

ACCOUNT:
$rawText''';

/// Small Tagalog function words that rarely appear in English sentences.
const _filWords = {
  'ang', 'ng', 'mga', 'ko', 'ako', 'ba', 'po', 'sa', 'na', 'ay', 'hindi', 'paano', 'ano', 'bakit', 'kailan',
  'saan', 'sino', 'yung', 'kasi', 'pero', 'naman', 'lang', 'akin', 'aking', 'niya', 'nila', 'namin', 'kami',
  'tayo', 'siya', 'ito', 'iyan', 'dito', 'doon', 'wala', 'meron', 'pwede', 'puwede', 'dapat', 'kung',
};

/// Replies in the language the worker actually wrote in, so a Filipino
/// question gets a Filipino answer even when the app is set to English.
bool looksFilipino(String text, {required bool fallback}) {
  final words = text.toLowerCase().split(RegExp(r'[^a-zñ]+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 2) return fallback;
  final hits = words.where(_filWords.contains).length;
  return hits / words.length >= 0.15 || (hits >= 2);
}
