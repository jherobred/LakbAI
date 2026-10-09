import 'package:flutter/material.dart';

/// A topic the chat can filter by. Typing any of its keywords turns it on.
class Topic {
  const Topic(this.id, this.en, this.fil, this.icon, this.color, this.keywords);
  final String id;
  final String en;
  final String fil;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  String label(bool fil) => fil ? this.fil : en;
}

const kTopics = <Topic>[
  Topic('contract', 'Contract', 'Kontrata', Icons.description_rounded, Color(0xFF2563EB), [
    'contract', 'contracts', 'kontrata', 'kasunduan', 'pinapirma', 'pinirmahan', 'pumirma', 'pirma', 'pipirma',
    'signed', 'sign', 'substitution', 'substitute', 'pinalitan', 'binago', 'papeles', 'bagong kontrata'
  ]),
  Topic('salary', 'Salary', 'Sahod', Icons.payments_rounded, Color(0xFF0EA5E9), [
    'salary', 'sahod', 'sweldo', 'suweldo', 'sueldo', 'wage', 'wages', 'pay', 'paid', 'payment', 'kita',
    'allowance', 'minimum wage', 'underpaid', 'kulang', 'dollars', 'usd', 'riyal', 'riyals', 'dirham', 'dinar', 'hkd'
  ]),
  Topic('hours', 'Work hours', 'Oras ng trabaho', Icons.schedule_rounded, Color(0xFF6366F1), [
    'hours', 'hour', 'oras', 'overtime', 'working hours', 'oras ng trabaho', 'puyat', 'walang tulog', 'buong araw', 'tulog'
  ]),
  Topic('rest_day', 'Rest day', 'Day off', Icons.weekend_rounded, Color(0xFF14B8A6), [
    'day off', 'dayoff', 'day-off', 'rest day', 'restday', 'pahinga', 'walang day off', 'off day', 'rest'
  ]),
  Topic('leave', 'Leave', 'Bakasyon', Icons.beach_access_rounded, Color(0xFF06B6D4), [
    'leave', 'vacation', 'bakasyon', 'sick leave', 'annual leave'
  ]),
  Topic('food_lodging', 'Food & room', 'Pagkain at tirahan', Icons.home_rounded, Color(0xFF10B981), [
    'food', 'pagkain', 'kain', 'gutom', 'hindi pinapakain', 'room', 'kwarto', 'kuwarto', 'tulugan',
    'accommodation', 'lodging', 'tirahan'
  ]),
  Topic('passport', 'Passport', 'Passport', Icons.badge_rounded, Color(0xFF8B5CF6), [
    'passport', 'pasaporte', 'iqama', 'documents', 'dokumento', 'visa', 'travel documents'
  ]),
  Topic('agency', 'Agency', 'Ahensya', Icons.apartment_rounded, Color(0xFF3B82F6), [
    'agency', 'ahensya', 'ahensiya', 'agensya', 'agent', 'manpower'
  ]),
  Topic('fees', 'Fees', 'Bayarin', Icons.receipt_long_rounded, Color(0xFFF59E0B), [
    'fee', 'fees', 'placement fee', 'bayad', 'binayaran', 'singil', 'sinisingil', 'utang', 'loan', 'deduction',
    'kaltas', 'binawas', 'deposit'
  ]),
  Topic('recruiter', 'Recruiter', 'Recruiter', Icons.person_search_rounded, Color(0xFFF97316), [
    'recruiter', 'handler', 'illegal recruiter', 'illegal recruitment', 'scam', 'budol', 'fixer', 'na-scam'
  ]),
  Topic('trafficking', 'Trafficking', 'Trafficking', Icons.warning_rounded, Color(0xFFE11D48), [
    'trafficking', 'trafficked', 'tourist visa', 'backdoor', 'escort', 'ibinenta', 'forced labor', 'sapilitan'
  ]),
  Topic('abuse', 'Abuse', 'Pang-aabuso', Icons.report_rounded, Color(0xFFE11D48), [
    'abuse', 'abused', 'binugbog', 'sinaktan', 'sinampal', 'pinalo', 'maltrato', 'harassment', 'hinipuan',
    'ginahasa', 'banta', 'threat', 'threatened', 'pinagbantaan', 'kinulong'
  ]),
  Topic('complaint', 'Complaint', 'Reklamo', Icons.gavel_rounded, Color(0xFF1D4ED8), [
    'complaint', 'complain', 'reklamo', 'kaso', 'magsampa', 'isampa', 'sumbong', 'nlrc', 'dmw', 'mwo', 'polo',
    'sena', 'report', 'i-report', 'legal action', 'demanda'
  ]),
  Topic('evidence', 'Evidence', 'Ebidensya', Icons.photo_library_rounded, Color(0xFF0891B2), [
    'evidence', 'ebidensya', 'proof', 'patunay', 'litrato', 'picture', 'photo', 'screenshot', 'recording'
  ]),
  Topic('deadline', 'Deadline', 'Taning', Icons.timer_rounded, Color(0xFF7C3AED), [
    'deadline', 'taning', 'prescription', 'ilang taon', 'huli na', 'too late', 'expired', 'hanggang kailan'
  ]),
  Topic('help', 'Get help', 'Tulong', Icons.support_agent_rounded, Color(0xFF16A34A), [
    'help', 'tulong', 'tulungan', 'saklolo', 'emergency', 'hotline', '1348', '1343', 'embassy', 'embahada',
    'konsulado', 'shelter'
  ]),
  Topic('repatriation', 'Going home', 'Pag-uwi', Icons.flight_land_rounded, Color(0xFF0D9488), [
    'uwi', 'umuwi', 'pauwi', 'makauwi', 'repatriation', 'ticket', 'flight', 'airfare', 'pamasahe'
  ]),
  Topic('health', 'Health', 'Kalusugan', Icons.medical_services_rounded, Color(0xFFDB2777), [
    'sick', 'may sakit', 'hospital', 'ospital', 'medical', 'gamot', 'injury', 'sugat'
  ]),
  Topic('country_hk', 'Hong Kong', 'Hong Kong', Icons.public_rounded, Color(0xFF2563EB), ['hong kong', 'hk']),
  Topic('country_sg', 'Singapore', 'Singapore', Icons.public_rounded, Color(0xFF2563EB), ['singapore', 'sg']),
  Topic('country_ksa', 'Saudi Arabia', 'Saudi Arabia', Icons.public_rounded, Color(0xFF2563EB),
      ['saudi', 'ksa', 'riyadh', 'jeddah', 'dammam', 'musaned']),
  Topic('country_uae', 'UAE', 'UAE', Icons.public_rounded, Color(0xFF2563EB), ['uae', 'dubai', 'abu dhabi', 'sharjah']),
  Topic('country_kw', 'Kuwait', 'Kuwait', Icons.public_rounded, Color(0xFF2563EB), ['kuwait']),
  Topic('country_qa', 'Qatar', 'Qatar', Icons.public_rounded, Color(0xFF2563EB), ['qatar', 'doha']),
];

Topic? topicById(String id) => kTopics.where((t) => t.id == id).firstOrNull;

/// One keyword found in the text, with its position for highlighting.
class TopicHit {
  const TopicHit(this.topic, this.start, this.end);
  final Topic topic;
  final int start;
  final int end;
}

/// Finds topic keywords as the user types. Longest keywords win, whole words only.
class KeywordDetector {
  KeywordDetector._() {
    final entries = <MapEntry<String, Topic>>[];
    for (final t in kTopics) {
      for (final k in t.keywords) {
        entries.add(MapEntry(k, t));
      }
    }
    entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    _patterns = [
      for (final e in entries) MapEntry(RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(e.key)}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true), e.value)
    ];
  }

  static final instance = KeywordDetector._();
  late final List<MapEntry<RegExp, Topic>> _patterns;

  List<TopicHit> detect(String text) {
    if (text.trim().isEmpty) return const [];
    final hits = <TopicHit>[];
    final taken = List<bool>.filled(text.length, false);
    for (final p in _patterns) {
      for (final m in p.key.allMatches(text)) {
        var free = true;
        for (var i = m.start; i < m.end; i++) {
          if (taken[i]) {
            free = false;
            break;
          }
        }
        if (!free) continue;
        for (var i = m.start; i < m.end; i++) {
          taken[i] = true;
        }
        hits.add(TopicHit(p.value, m.start, m.end));
      }
    }
    hits.sort((a, b) => a.start.compareTo(b.start));
    return hits;
  }

  /// Topics in the order they first appear.
  List<Topic> topicsIn(String text) {
    final seen = <String>{};
    final out = <Topic>[];
    for (final h in detect(text)) {
      if (seen.add(h.topic.id)) out.add(h.topic);
    }
    return out;
  }
}
