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
  'kinuha ng amo ang passport ko dito sa riyadh': ['country_ksa_domestic', 'passport_abroad'],
  'can my employer in jeddah keep my passport': ['country_ksa_domestic', 'passport_abroad'],
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

/// Fresh phrasings that were not used to pick keywords, to measure how well search generalizes.
/// The committed knowledge base before this set existed scored 12/26.
const _heldOut = <String, List<String>>{
  'hawak ng employer ko ang passport ko, bawal ba yun': ['withholding_documents', 'passport_abroad', 'country_uae_domestic', 'country_kw_domestic'],
  'can my employer keep my iqama': ['withholding_documents', 'passport_abroad', 'country_ksa_domestic', 'country_ksa_musaned'],
  'mas maliit ang sahod sa bagong kontrata': ['substitution_definition', 'first_steps_substitution', 'renegotiated_terms', 'what_to_compare'],
  'my agency is charging me 50,000 pesos': ['fees_hsw', 'recruiter_red_flags', 'loans_deductions'],
  'pinapatrabaho ako ng 18 oras': ['hsw_rest'],
  'I work every day with no rest': ['hsw_rest'],
  'binubugbog ako ng amo ko, tulungan niyo ako': ['abuse_help', 'hotline_1343', 'ran_away_shelter'],
  'my boss hits me': ['abuse_help', 'hotline_1343'],
  'gusto ko nang umuwi pero ayaw ng amo ko': ['repatriation', 'ran_away_shelter'],
  'hindi ako binigyan ng sahod ngayong buwan': ['unpaid_wages'],
  'my salary has been delayed for two months': ['unpaid_wages'],
  'paano mag file ng kaso laban sa agency': ['where_home', 'criminal_case', 'agency_joint_liability'],
  'how do I report an illegal recruiter': ['criminal_case', 'recruiter_red_flags', 'hotline_1343'],
  'nagkasakit ako dito sa saudi': ['compulsory_insurance', 'abuse_help'],
  'what benefits does owwa give': ['owwa_membership'],
  'kinuha nila ang cellphone ko': ['phone_privacy', 'abuse_help'],
  'na-terminate ako sa hong kong, ano ang gagawin ko': ['country_hk_two_week', 'illegal_dismissal_pay'],
  'sabi ng recruiter tourist visa lang daw': ['recruiter_red_flags', 'trafficking'],
  'I signed a new contract at the airport': ['pressure_to_sign', 'renegotiated_terms'],
  'pwede ba akong magreklamo kahit nandito pa ako': ['where_abroad', 'ladder_overview'],
  'paid leave for maids in dubai': ['country_uae_domestic'],
  'the employer did not give me food for days': ['abuse_help', 'hsw_free_board'],
  'ilang oras ang trabaho sa qatar': ['country_qa_domestic'],
  'magkano ang singil ng agency sa hongkong': ['country_hk_agency_fee'],
  'overstaying ako, matutulungan pa ba ng embassy': ['undocumented_help'],
  'is there free legal help for OFWs': ['aksyon_fund', 'undocumented_help'],
};

List<String> _misses(KnowledgeBase kb, Map<String, List<String>> cases) => [
      for (final c in cases.entries)
        if (!kb
            .search(c.key, topics: KeywordDetector.instance.topicsIn(c.key).map((t) => t.id).toSet(), k: 2)
            .any((e) => c.value.contains(e.id)))
          c.key,
    ];

void main() {
  test('held-out questions stay at or above 24/26', () {
    final kb = KnowledgeBase.parse(File('assets/kb/knowledge.json').readAsStringSync());
    final misses = _misses(kb, _heldOut);
    // ignore: avoid_print
    print('held-out top-2 hits: ${_heldOut.length - misses.length}/${_heldOut.length}, missed: $misses');
    expect(_heldOut.length - misses.length, greaterThanOrEqualTo(24));
  });

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
