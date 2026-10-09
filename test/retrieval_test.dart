import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kontrata/knowledge/kb.dart';
import 'package:kontrata/knowledge/topics.dart';

/// Questions the way workers type them, and the entries that answer them.
/// The chat sends the top 2 entries to the model, so a hit means one of the
/// accepted ids is in the top 2.
const _cases = <String, List<String>>{
  'kinuha ang passport ko': ['withholding_documents'],
  'my employer took my passport': ['withholding_documents'],
  'tinago ng amo ko ang pasaporte ko': ['withholding_documents'],
  'pinalitan ang kontrata ko pagdating ko dito': ['substitution_definition', 'first_steps_substitution', 'renegotiated_terms'],
  'they gave me a new contract with a lower salary when I arrived': ['substitution_definition', 'first_steps_substitution', 'renegotiated_terms'],
  'pinapapirma ako ng bagong kontrata': ['pressure_to_sign', 'renegotiated_terms', 'first_steps_substitution'],
  'magkano ang minimum na sahod ng kasambahay': ['hsw_minimum_wage'],
  'what is the minimum salary for domestic helpers': ['hsw_minimum_wage'],
  'wala akong day off': ['hsw_rest'],
  'ilang oras dapat ang tulog ko': ['hsw_rest'],
  'pinagbabayad ako ng placement fee': ['fees_hsw'],
  'do I need to pay a placement fee as a household worker': ['fees_hsw'],
  'hanggang kailan ako pwedeng magreklamo': ['deadlines'],
  'is it too late to file a case when I get home': ['deadlines', 'where_home'],
  'saan ako magrereklamo pag-uwi ko sa pilipinas': ['where_home'],
  'where can I get help here in Riyadh': ['where_abroad', 'hotline_1348'],
  'sinasaktan ako ng amo ko': ['abuse_help', 'hotline_1343'],
  'my employer does not feed me': ['abuse_help', 'hsw_free_board'],
  'who pays for my ticket home': ['repatriation', 'hsw_free_board'],
  'sino ang magbabayad ng pamasahe ko pauwi': ['repatriation', 'hsw_free_board'],
  'paano malalaman kung legit ang agency': ['verify_license', 'recruiter_red_flags'],
  'the recruiter told me to leave as a tourist': ['recruiter_red_flags', 'trafficking'],
  'tinanggal ako sa trabaho nang walang dahilan': ['illegal_dismissal_pay'],
  'I was fired without a valid reason, can I get paid': ['illegal_dismissal_pay'],
  'may libreng abogado ba para sa ofw': ['aksyon_fund'],
  'pwede bang ebidensya ang litrato ng kontrata': ['evidence_rules'],
  'ano ang sena': ['sena'],
  'can I still go after my agency in manila': ['agency_joint_liability', 'where_home'],
  'day off in hong kong': ['country_hk_rest'],
  'minimum wage for helpers in hong kong': ['country_hk_wage'],
  'baka tingnan ng amo ko ang cellphone ko': ['phone_privacy'],
  'contract on musaned in saudi': ['country_ksa_musaned'],
  'rest day sa singapore': ['country_sg_rest'],
  'nakakulong ako sa bahay ng amo': ['abuse_help', 'hotline_1343', 'trafficking'],
  'ano ang dapat kong ikumpara sa dalawang kontrata': ['what_to_compare'],
  'ano ang mga opsyon ko': ['ladder_overview'],
  'ilang araw ang bakasyon ko': ['hsw_leave'],
  'emergency hotline': ['hotline_1348', 'hotline_1343'],
  'may insurance ba ako bilang ofw': ['compulsory_insurance', 'owwa_membership'],
  'I got sick, who pays the hospital bill': ['compulsory_insurance', 'abuse_help'],
  'tumakas ako sa amo ko saan ako pupunta': ['ran_away_shelter'],
  'I ran away from my employer': ['ran_away_shelter'],
  'day off ng kasambahay sa kuwait': ['country_kw_domestic'],
  'my sponsor in dubai keeps my passport': ['country_uae_domestic', 'withholding_documents'],
  'minimum wage in qatar': ['country_qa_domestic'],
  'ano ang benepisyo ng owwa': ['owwa_membership'],
  'natapos ang kontrata ko sa hong kong, ilang araw pa ako pwedeng manatili': ['country_hk_two_week'],
  'how much can a hong kong agency charge me': ['country_hk_agency_fee'],
  'tatlong buwan na akong hindi pinapasahod': ['unpaid_wages'],
  'binabawasan ng amo ang sahod ko': ['loans_deductions'],
  'wala akong papeles, matutulungan pa ba ako': ['undocumented_help'],
  'pinilit akong mangutang sa lending ng agency': ['loans_deductions'],
};

void main() {
  test('chat retrieval puts an answering entry in the top 2', () {
    final kb = KnowledgeBase.parse(File('assets/kb/knowledge.json').readAsStringSync());
    final misses = <String>[];
    for (final c in _cases.entries) {
      final topics = KeywordDetector.instance.topicsIn(c.key).map((t) => t.id).toSet();
      final got = kb.search(c.key, topics: topics, k: 2).map((e) => e.id).toList();
      if (!got.any(c.value.contains)) misses.add('${c.key} -> $got, want ${c.value}');
    }
    final hits = _cases.length - misses.length;
    // ignore: avoid_print
    print('top-2 hits: $hits/${_cases.length}\n${misses.join('\n')}');
    expect(misses, isEmpty);
  });

  test('every entry is complete and every id is unique', () {
    final kb = KnowledgeBase.parse(File('assets/kb/knowledge.json').readAsStringSync());
    final ids = kb.entries.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in kb.entries) {
      expect([e.titleEn, e.titleFil, e.bodyEn, e.bodyFil, e.sourceLabel, e.sourceUrl].every((s) => s.trim().isNotEmpty), isTrue, reason: e.id);
      expect(e.topics.every((t) => topicById(t) != null), isTrue, reason: '${e.id} has an unknown topic');
    }
  });
}
