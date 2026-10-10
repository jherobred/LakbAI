import 'package:flutter_test/flutter_test.dart';
import 'package:kontrata/ai/ai_service.dart';
import 'package:kontrata/ai/prompts.dart';

// Replies below are real Qwen3 0.6B outputs (LM Studio, q4_k_m) for the app's prompts.
void main() {
  test('cleanModelText drops copied format words and keeps one Source line at the end', () {
    const raw = '<think>\n\n</think>\n\n'
        '- One short sentence that answers the question: If you are hurt, call 1348.\n'
        '- - Go to the Migrant Workers Office for shelter.\n'
        '**Bold**\n'
        '- Bullet points starting with "- ":\n'
        '- Keep your payslips."\n'
        '- **Source**: RA 8042 Sec. 15.\n'
        '- **Agency** pays for your ticket home.\n\n'
        'Source: RA 8042 Sec. 15.';
    expect(
      cleanModelText(raw),
      '- If you are hurt, call 1348.\n'
      '- Go to the Migrant Workers Office for shelter.\n'
      '- Keep your payslips.\n'
      '- **Agency** pays for your ticket home.\n\n'
      'Source: RA 8042 Sec. 15.',
    );
  });

  test('cleanModelText moves a trailing inline Source to its own line and drops "<law>"', () {
    expect(
      cleanModelText('A lower salary is not allowed without DMW approval. Source: RA 8042 Sec. 6.\n- Keep both contracts.\n- **Source: <law>**.'),
      'A lower salary is not allowed without DMW approval.\n- Keep both contracts.\n\nSource: RA 8042 Sec. 6.',
    );
  });

  test('cleanModelText removes a looping line but keeps lines that differ by a number', () {
    const loop = '- Pagsasabay ng pagbabagyo: ay 8 oras na pahinga araw-araw, 1 day off kada linggo.\n'
        '- Pagbabagyo ng pagbabagyo: ay 8 oras na pahinga araw-araw, 1 day off kada linggo.';
    expect(cleanModelText(loop).split('\n'), hasLength(1));
    const facts = 'On March 3 my employer did not pay me.\nOn April 3 my employer did not pay me.';
    expect(cleanModelText(facts), facts);
  });

  test('isLooping stops repeats and a second Source line, not normal answers', () {
    expect(isLooping('- Money claims: **3 years** (Labor Code Art. 306).\n- Illegal recruitment: **5 years**, or 20 if large-scale.\n'), isFalse);
    expect(isLooping('- Pagsasabay ng pagbabagyo ay 8 oras na pahinga.\n- Pagsasabay ng pagbabagyo ay 8 oras na pahinga.\n'), isTrue);
    expect(isLooping('- Call 1348.\nSource: DMW / OWWA.\n- Go to the MWO.\nSource: DMW / OWWA.\n'), isTrue);
    expect(isLooping('ng amo ng amo ko ng amo ng amo ko ng amo ng amo ko ng amo ng amo ko'), isTrue);
  });

  test('isFollowUp keeps the earlier exchange only for follow-ups', () {
    for (final q in ['what about in Kuwait?', 'paano kung ayaw nila?', 'how much?', 'e sa Hong Kong?', 'bakit?']) {
      expect(isFollowUp(q), isTrue, reason: q);
    }
    for (final q in ['kinuha ang passport ko', 'sinasaktan ako ng amo ko', 'who pays for my ticket home', 'wala akong day off']) {
      expect(isFollowUp(q), isFalse, reason: q);
    }
  });

  test('a new question carries no earlier exchange and ends with the format line', () {
    final p = buildPrompt(question: 'kinuha ang passport ko', context: const [], fil: true, lastExchange: 'Worker: hi\nLakbAI: hello');
    expect(p, isNot(contains('EARLIER')));
    // Qwen3 0.6B is the default model and answers in English.
    expect(p.trim().split('\n').last, startsWith('Reply in simple English'));
  });
}
