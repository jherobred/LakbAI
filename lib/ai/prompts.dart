import '../knowledge/kb.dart';

/// Keeps the small on-device model grounded in the knowledge base and gentle in tone.
String systemPrompt({required bool fil}) => '''
You are Kontrata, a calm helper for Overseas Filipino Workers (OFWs). You run fully offline on the worker's phone.
Rules:
- Reply in ${fil ? 'simple Filipino (Taglish is fine)' : 'simple English'}. Short sentences. At most 120 words.
- Use ONLY the facts in CONTEXT. If CONTEXT does not answer it, say you are not sure and suggest calling 1348 or asking the Migrant Workers Office (MWO).
- Never invent laws, numbers, phone numbers or deadlines.
- Never push the worker to confront the employer. Offer the safest option first. Keeping evidence quietly is always a valid choice.
- If they mention danger, abuse or trafficking, put safety first: 1343 (trafficking) or 1348 (DMW/OWWA 24/7).
- Use short bullet points for steps. End with one line naming the law or source you used.
- You are not a lawyer. Do not promise outcomes.''';

String buildContext(List<KbEntry> entries, {required bool fil}) {
  final b = StringBuffer('CONTEXT:\n');
  for (final e in entries) {
    b.writeln('- ${e.titleEn}: ${e.bodyEn} (Source: ${e.sourceLabel})');
  }
  return b.toString();
}

String buildPrompt({required String question, required List<KbEntry> context, required bool fil, String? lastExchange}) {
  final b = StringBuffer(buildContext(context, fil: fil));
  if (lastExchange != null && lastExchange.isNotEmpty) {
    b.writeln('\nEARLIER IN THIS CHAT:\n$lastExchange');
  }
  b.writeln('\nWORKER ASKS: $question');
  return b.toString();
}

/// Used when no model is installed yet, or the phone is too busy:
/// answer straight from the knowledge base so the app is never useless.
String extractiveAnswer(List<KbEntry> entries, {required bool fil}) {
  if (entries.isEmpty) {
    return fil
        ? 'Wala akong eksaktong sagot dito. Puwede kang tumawag sa 1348 (DMW/OWWA, 24/7) o lumapit sa Migrant Workers Office sa embahada.'
        : "I don't have an exact answer for that. You can call 1348 (DMW/OWWA, 24/7) or visit the Migrant Workers Office at the embassy.";
  }
  final b = StringBuffer(fil ? 'Ito ang alam ko:\n\n' : "Here's what I know:\n\n");
  for (final e in entries.take(2)) {
    b.writeln('• ${e.title(fil)}');
    b.writeln(e.body(fil));
    b.writeln();
  }
  return b.toString().trim();
}

String explainChangesPrompt({required String diffSummary, required bool fil}) => '''
CONTEXT:
- Changing a DMW-verified contract to the worker's disadvantage without DMW approval is illegal (Labor Code Art. 34(i); RA 8042 Sec. 6).
- The Philippine agency stays jointly liable for money claims even if the contract was changed abroad (RA 8042 Sec. 10).
- Money claims can be filed within 3 years (Labor Code Art. 306).

CHANGES FOUND BETWEEN THE VERIFIED CONTRACT AND THE NEW ONE:
$diffSummary

Explain to the worker in ${fil ? 'simple Filipino' : 'simple English'}, in under 110 words, what these changes mean for them. Be calm. Do not tell them to confront anyone. End by saying they can keep this evidence and decide later.''';

String statementPrompt({required String rawText, required bool fil}) => '''
Rewrite the worker's account below as a clear, first-person statement for an incident report, in ${fil ? 'Filipino' : 'English'}.
Keep every fact, date, name and number exactly as given. Do not add facts. Use short paragraphs in time order. No headings.

ACCOUNT:
$rawText''';
