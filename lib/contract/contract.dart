/// Contract terms pulled out of OCR text, plus the comparison that finds
/// substituted clauses. Pure Dart and rule-based on purpose: numbers in a
/// legal comparison should never depend on a language model guessing.
library;

class ContractTerms {
  ContractTerms({
    this.salary,
    this.currency,
    this.workHoursPerDay,
    this.restHoursPerDay,
    this.restDays,
    this.restPeriod,
    this.leaveDays,
    this.durationMonths,
    this.position,
    this.employer,
    this.worksite,
    this.freeFood,
    this.freeLodging,
    this.airfare,
    this.deductionClause = false,
    this.passportHeldClause = false,
    this.rawText = '',
  });

  double? salary;
  String? currency;
  int? workHoursPerDay;
  int? restHoursPerDay;
  int? restDays; // count
  String? restPeriod; // 'week' | 'month'
  int? leaveDays;
  int? durationMonths;
  String? position;
  String? employer;
  String? worksite;
  bool? freeFood;
  bool? freeLodging;
  bool? airfare;
  bool deductionClause;
  bool passportHeldClause;
  String rawText;

  int get foundCount => [
        salary,
        workHoursPerDay,
        restHoursPerDay,
        restDays,
        leaveDays,
        durationMonths,
        position,
        employer,
        worksite,
        freeFood,
        freeLodging,
        airfare,
      ].where((v) => v != null).length;

  String get salaryLabel => salary == null ? '—' : '${currency ?? ''} ${_fmtNum(salary!)}'.trim();
  String get restDayLabel => restDays == null ? '—' : '$restDays / ${restPeriod ?? 'week'}';

  Map<String, dynamic> toJson() => {
        'salary': salary,
        'currency': currency,
        'workHoursPerDay': workHoursPerDay,
        'restHoursPerDay': restHoursPerDay,
        'restDays': restDays,
        'restPeriod': restPeriod,
        'leaveDays': leaveDays,
        'durationMonths': durationMonths,
        'position': position,
        'employer': employer,
        'worksite': worksite,
        'freeFood': freeFood,
        'freeLodging': freeLodging,
        'airfare': airfare,
        'deductionClause': deductionClause,
        'passportHeldClause': passportHeldClause,
        'rawText': rawText,
      };

  factory ContractTerms.fromJson(Map<String, dynamic> j) => ContractTerms(
        salary: (j['salary'] as num?)?.toDouble(),
        currency: j['currency'] as String?,
        workHoursPerDay: j['workHoursPerDay'] as int?,
        restHoursPerDay: j['restHoursPerDay'] as int?,
        restDays: j['restDays'] as int?,
        restPeriod: j['restPeriod'] as String?,
        leaveDays: j['leaveDays'] as int?,
        durationMonths: j['durationMonths'] as int?,
        position: j['position'] as String?,
        employer: j['employer'] as String?,
        worksite: j['worksite'] as String?,
        freeFood: j['freeFood'] as bool?,
        freeLodging: j['freeLodging'] as bool?,
        airfare: j['airfare'] as bool?,
        deductionClause: j['deductionClause'] as bool? ?? false,
        passportHeldClause: j['passportHeldClause'] as bool? ?? false,
        rawText: j['rawText'] as String? ?? '',
      );
}

String _fmtNum(double v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  final ip = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return parts.length > 1 ? '$ip.${parts[1]}' : ip;
}

String fmtMoney(double v) => _fmtNum(v);

// ---------------------------------------------------------------- Extraction

const _numberWords = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'eighteen': 18,
  'twenty': 20, 'twenty-one': 21, 'twenty-four': 24, 'thirty': 30, 'thirty-six': 36,
  'isa': 1, 'dalawa': 2, 'tatlo': 3, 'apat': 4, 'lima': 5, 'anim': 6, 'pito': 7, 'walo': 8, 'siyam': 9, 'sampu': 10,
};

/// Currency aliases normalized to ISO-like codes.
const _currencies = {
  'us\$': 'USD', 'usd': 'USD', 'us dollars': 'USD', 'dollars': 'USD', 'u.s. dollars': 'USD',
  'sar': 'SAR', 'riyal': 'SAR', 'riyals': 'SAR', 'saudi riyals': 'SAR',
  'aed': 'AED', 'dirham': 'AED', 'dirhams': 'AED',
  'kwd': 'KWD', 'kuwaiti dinar': 'KWD', 'kd': 'KWD',
  'qar': 'QAR', 'qatari riyal': 'QAR', 'qr': 'QAR',
  'hk\$': 'HKD', 'hkd': 'HKD', 'hong kong dollars': 'HKD',
  'sgd': 'SGD', 's\$': 'SGD',
  'nt\$': 'TWD', 'twd': 'TWD', 'ntd': 'TWD',
  'myr': 'MYR', 'rm': 'MYR',
  'jpy': 'JPY', 'yen': 'JPY', '¥': 'JPY',
  'php': 'PHP', '₱': 'PHP', 'pesos': 'PHP',
  '\$': 'USD',
};

final _curAlt = (_currencies.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|');

int? _num(String? s) {
  if (s == null) return null;
  final digits = RegExp(r'\d+').firstMatch(s);
  if (digits != null) return int.tryParse(digits.group(0)!);
  return _numberWords[s.trim().toLowerCase()];
}

/// Number written as "two (2)", "2", or "two".
const _n = r'(\d{1,3}|\(\s*\d{1,3}\s*\)|[a-z]+(?:-[a-z]+)?\s*\(\s*\d{1,3}\s*\)|[a-z]+(?:-[a-z]+)?)';

ContractTerms extractTerms(String text) {
  final raw = text;
  final t = text.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll('\r', '');
  final lower = t.toLowerCase();
  final terms = ContractTerms(rawText: raw);

  // Salary: "Basic monthly salary: USD 500.00" or "salary of 1,500 SAR".
  final salaryRe = RegExp(
    '(?:basic\\s+)?(?:monthly\\s+)?(?:salary|wage|sahod|pay)[^\\n\\d]{0,40}?(?<![a-z])($_curAlt)\\s?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)',
    caseSensitive: false,
  );
  final salaryRe2 = RegExp(
    '(?:basic\\s+)?(?:monthly\\s+)?(?:salary|wage|sahod|pay)[^\\n]{0,40}?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)\\s?($_curAlt)\\b',
    caseSensitive: false,
  );
  final m1 = salaryRe.firstMatch(t);
  final m2 = salaryRe2.firstMatch(t);
  if (m1 != null && (m2 == null || m1.start <= m2.start)) {
    terms.currency = _currencies[m1.group(1)!.toLowerCase()] ?? m1.group(1)!.toUpperCase();
    terms.salary = double.tryParse(m1.group(2)!.replaceAll(',', ''));
  } else if (m2 != null) {
    terms.currency = _currencies[m2.group(2)!.toLowerCase()] ?? m2.group(2)!.toUpperCase();
    terms.salary = double.tryParse(m2.group(1)!.replaceAll(',', ''));
  }

  // Daily rest: "at least eight (8) continuous hours of rest".
  final restH = RegExp('$_n\\s*(?:continuous|consecutive|uninterrupted)?\\s*hours?\\s+of\\s+(?:continuous\\s+|uninterrupted\\s+)?rest', caseSensitive: false)
          .firstMatch(lower) ??
      RegExp('rest\\s+(?:period\\s+)?of\\s+(?:at\\s+least\\s+)?$_n\\s*(?:continuous\\s+|consecutive\\s+)?hours?', caseSensitive: false)
          .firstMatch(lower);
  terms.restHoursPerDay = _num(restH?.group(1));

  // Working hours: "working hours: 10 hours per day" / "work for 12 hours a day".
  final workH = RegExp('(?:working|work|duty)\\s+hours?[^\\n\\d]{0,25}$_n\\s*hours?', caseSensitive: false).firstMatch(lower) ??
      RegExp('work(?:s|ing)?\\s+(?:for\\s+)?$_n\\s*hours?\\s*(?:per|a|each)\\s*day', caseSensitive: false).firstMatch(lower);
  terms.workHoursPerDay = _num(workH?.group(1));

  // Rest days: "one (1) rest day per week" / "1 day off every month".
  final restD = RegExp('$_n\\s*(?:paid\\s+)?(?:rest\\s*days?|days?\\s*off|day-off)\\s*(?:per|a|each|every|in\\s+a)\\s*(week|month)', caseSensitive: false)
      .firstMatch(lower);
  if (restD != null) {
    terms.restDays = _num(restD.group(1));
    terms.restPeriod = restD.group(2);
  } else {
    final restD2 = RegExp('(?:rest\\s*day|day\\s*off)[^\\n.]{0,40}?(?:per|a|each|every)\\s*(week|month)', caseSensitive: false).firstMatch(lower);
    if (restD2 != null) {
      terms.restDays = 1;
      terms.restPeriod = restD2.group(1);
    } else if (RegExp(r'no\s+(?:rest\s*day|day\s*off)').hasMatch(lower)) {
      terms.restDays = 0;
      terms.restPeriod = 'week';
    }
  }

  // Leave: "fifteen (15) calendar days of vacation leave with full pay".
  final leave = RegExp('$_n\\s*(?:calendar\\s+|working\\s+)?days?\\s+(?:of\\s+)?(?:paid\\s+)?(?:vacation|annual)\\s+leave', caseSensitive: false).firstMatch(lower) ??
      RegExp('(?:vacation|annual)\\s+leave[^\\n\\d]{0,40}$_n\\s*(?:calendar\\s+)?days?', caseSensitive: false).firstMatch(lower);
  terms.leaveDays = _num(leave?.group(1));

  // Duration: "for a period of two (2) years" / "contract duration: 24 months".
  final dur = RegExp('(?:period|duration|term)\\s+(?:of\\s+)?(?:employment\\s+)?(?:is\\s+|shall\\s+be\\s+)?[:\\-]?\\s*$_n\\s*(years?|months?)', caseSensitive: false).firstMatch(lower) ??
      RegExp('$_n\\s*(years?|months?)\\s*(?:commencing|starting|from|contract)', caseSensitive: false).firstMatch(lower);
  if (dur != null) {
    final n = _num(dur.group(1));
    if (n != null) terms.durationMonths = dur.group(2)!.startsWith('year') ? n * 12 : n;
  }

  // Position, employer, worksite from labelled lines.
  terms.position = _labelValue(t, ['position', 'job title', 'designation', 'employed as', 'occupation']);
  terms.employer = _labelValue(t, ["employer's name", 'name of employer', 'employer name', 'employer']);
  terms.worksite = _labelValue(t, ['site of employment', 'worksite', 'work site', 'place of work', 'country of employment']);

  // Benefits.
  if (RegExp(r'free\s+(?:food|meals|board)|food\s+(?:shall\s+be\s+)?(?:provided\s+)?free').hasMatch(lower)) terms.freeFood = true;
  if (RegExp(r'food\s+allowance|worker\s+shall\s+(?:pay|provide)\s+(?:for\s+)?(?:own\s+|his\s+|her\s+)?food').hasMatch(lower)) {
    terms.freeFood ??= false;
  }
  if (RegExp(r'free\s+(?:and\s+)?(?:suitable\s+)?(?:living\s+quarters|accommodation|lodging|housing|board and lodging)').hasMatch(lower)) {
    terms.freeLodging = true;
  }
  if (RegExp(r'(?:air\s*fare|air\s*ticket|transportation)[^\n.]{0,60}(?:borne|paid|provided)\s+by\s+(?:the\s+)?employer|free\s+(?:round[- ]trip\s+)?(?:air\s*fare|transportation)').hasMatch(lower)) {
    terms.airfare = true;
  }
  if (RegExp(r'(?:air\s*fare|ticket)[^\n.]{0,60}(?:borne|paid|shouldered)\s+by\s+(?:the\s+)?(?:worker|employee)').hasMatch(lower)) {
    terms.airfare = false;
  }
  terms.deductionClause = RegExp(r'deduct(?:ed|ion|ions)?\s+(?:from\s+)?(?:the\s+)?(?:worker|employee|salary|wages)|salary\s+deduction').hasMatch(lower);
  terms.passportHeldClause =
      RegExp(r'(?:passport|travel\s+documents?)[^\n.]{0,60}(?:kept|keep|held|hold|retain(?:ed)?|in\s+the\s+custody)\s+(?:by|of)?\s*(?:the\s+)?(?:employer|agency|sponsor)').hasMatch(lower) ||
          RegExp(r'(?:employer|agency|sponsor)\s+(?:shall|will|may)\s+(?:keep|hold|retain)\s+(?:the\s+)?(?:worker.s\s+|employee.s\s+)?(?:passport|travel)').hasMatch(lower);

  return terms;
}

String? _labelValue(String text, List<String> labels) {
  for (final l in labels) {
    final m = RegExp('${RegExp.escape(l)}\\s*[:\\-]\\s*(?:(?:a|an|the)\\s+)?([^\\n,;]{2,60})', caseSensitive: false).firstMatch(text);
    if (m != null) {
      final v = m.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (v.isNotEmpty && !RegExp(r'^_+$').hasMatch(v)) return v;
    }
  }
  return null;
}

// ---------------------------------------------------------------- Comparison

enum Severity { high, medium, info, better }

class Discrepancy {
  Discrepancy({
    required this.field,
    required this.titleEn,
    required this.titleFil,
    required this.before,
    required this.after,
    required this.severity,
    required this.noteEn,
    required this.noteFil,
    this.kbIds = const [],
  });

  final String field;
  final String titleEn;
  final String titleFil;
  final String before;
  final String after;
  final Severity severity;
  final String noteEn;
  final String noteFil;
  final List<String> kbIds;

  String title(bool fil) => fil ? titleFil : titleEn;
  String note(bool fil) => fil ? noteFil : noteEn;

  Map<String, dynamic> toJson() => {
        'field': field,
        'titleEn': titleEn,
        'titleFil': titleFil,
        'before': before,
        'after': after,
        'severity': severity.name,
        'noteEn': noteEn,
        'noteFil': noteFil,
        'kbIds': kbIds,
      };

  factory Discrepancy.fromJson(Map<String, dynamic> j) => Discrepancy(
        field: j['field'] as String,
        titleEn: j['titleEn'] as String,
        titleFil: j['titleFil'] as String,
        before: j['before'] as String,
        after: j['after'] as String,
        severity: Severity.values.byName(j['severity'] as String),
        noteEn: j['noteEn'] as String,
        noteFil: j['noteFil'] as String,
        kbIds: (j['kbIds'] as List?)?.cast<String>() ?? const [],
      );
}

String _yn(bool? v, bool fil) => v == null ? '—' : (v ? (fil ? 'Mayroon' : 'Yes') : (fil ? 'Wala' : 'No'));

String _months(int? m) {
  if (m == null) return '—';
  if (m % 12 == 0) return '${m ~/ 12} yr';
  return '$m mo';
}

bool _isDomestic(String? position) {
  if (position == null) return false;
  return RegExp(r'household|domestic|helper|kasambahay|housemaid|maid|nanny|caregiver', caseSensitive: false).hasMatch(position);
}

/// Compares the DMW-verified contract with the one handed to the worker.
/// Also checks the new contract against known minimum standards.
List<Discrepancy> compareContracts(ContractTerms verified, ContractTerms current, {required bool fil}) {
  final out = <Discrepancy>[];
  final sub = ['substitution_definition', 'agency_joint_liability'];

  // Salary
  if (verified.salary != null && current.salary != null) {
    if (verified.currency != null && current.currency != null && verified.currency != current.currency) {
      out.add(Discrepancy(
        field: 'currency',
        titleEn: 'Salary currency changed',
        titleFil: 'Pinalitan ang currency ng sahod',
        before: verified.salaryLabel,
        after: current.salaryLabel,
        severity: Severity.high,
        noteEn: 'A different currency can hide a pay cut. Ask the MWO to check the value against your verified salary.',
        noteFil: 'Puwedeng maitago ng ibang currency ang bawas sa sahod. Ipa-check sa MWO ang katumbas nito.',
        kbIds: sub,
      ));
    } else if (current.salary! < verified.salary!) {
      final cut = verified.salary! - current.salary!;
      final pct = (cut / verified.salary! * 100).round();
      out.add(Discrepancy(
        field: 'salary',
        titleEn: 'Salary lowered by $pct%',
        titleFil: 'Ibinaba ang sahod nang $pct%',
        before: verified.salaryLabel,
        after: current.salaryLabel,
        severity: Severity.high,
        noteEn: 'You would lose ${current.currency ?? ''} ${fmtMoney(cut)} every month. Over 2 years that is ${current.currency ?? ''} ${fmtMoney(cut * 24)} you can still claim within 3 years.',
        noteFil: 'Mawawalan ka ng ${current.currency ?? ''} ${fmtMoney(cut)} kada buwan. Sa 2 taon, ${current.currency ?? ''} ${fmtMoney(cut * 24)} ito na puwede mo pang habulin sa loob ng 3 taon.',
        kbIds: [...sub, 'deadlines'],
      ));
    } else if (current.salary! > verified.salary!) {
      out.add(Discrepancy(
        field: 'salary',
        titleEn: 'Salary is higher',
        titleFil: 'Mas mataas ang sahod',
        before: verified.salaryLabel,
        after: current.salaryLabel,
        severity: Severity.better,
        noteEn: 'A better term is fine, but have the MWO verify any new contract.',
        noteFil: 'Ayos ang mas magandang kondisyon, pero ipa-verify pa rin sa MWO ang bagong kontrata.',
        kbIds: const ['renegotiated_terms'],
      ));
    }
  } else if (verified.salary != null && current.salary == null) {
    out.add(Discrepancy(
      field: 'salary',
      titleEn: 'Salary not found in the new contract',
      titleFil: 'Walang nakitang sahod sa bagong kontrata',
      before: verified.salaryLabel,
      after: '—',
      severity: Severity.medium,
      noteEn: 'The scan could not read a salary. Check the paper yourself or retake the photo.',
      noteFil: 'Hindi nabasa ang sahod. Tingnan mismo ang papel o kunan ulit ng litrato.',
    ));
  }

  // Daily rest
  if (verified.restHoursPerDay != null && current.restHoursPerDay != null && current.restHoursPerDay! < verified.restHoursPerDay!) {
    out.add(Discrepancy(
      field: 'restHours',
      titleEn: 'Less daily rest',
      titleFil: 'Mas kaunting pahinga araw-araw',
      before: '${verified.restHoursPerDay} h',
      after: '${current.restHoursPerDay} h',
      severity: Severity.high,
      noteEn: 'Your verified contract gives ${verified.restHoursPerDay} hours of rest a day.',
      noteFil: 'Sa na-verify mong kontrata, ${verified.restHoursPerDay} oras ang pahinga mo kada araw.',
      kbIds: [...sub, 'hsw_rest'],
    ));
  }

  // Working hours
  if (verified.workHoursPerDay != null && current.workHoursPerDay != null && current.workHoursPerDay! > verified.workHoursPerDay!) {
    out.add(Discrepancy(
      field: 'workHours',
      titleEn: 'Longer working hours',
      titleFil: 'Mas mahabang oras ng trabaho',
      before: '${verified.workHoursPerDay} h/day',
      after: '${current.workHoursPerDay} h/day',
      severity: Severity.high,
      noteEn: '${current.workHoursPerDay! - verified.workHoursPerDay!} more hours of work every day.',
      noteFil: '${current.workHoursPerDay! - verified.workHoursPerDay!} oras na dagdag na trabaho araw-araw.',
      kbIds: sub,
    ));
  }

  // Rest days
  if (verified.restDays != null && current.restDays != null) {
    final vWeek = verified.restDays! * (verified.restPeriod == 'month' ? 1 / 4.33 : 1);
    final cWeek = current.restDays! * (current.restPeriod == 'month' ? 1 / 4.33 : 1);
    if (cWeek + 0.01 < vWeek) {
      out.add(Discrepancy(
        field: 'restDays',
        titleEn: current.restDays == 0 ? 'Rest day removed' : 'Fewer rest days',
        titleFil: current.restDays == 0 ? 'Tinanggal ang day off' : 'Mas kaunting day off',
        before: verified.restDayLabel,
        after: current.restDays == 0 ? (fil ? 'Wala' : 'None') : current.restDayLabel,
        severity: Severity.high,
        noteEn: 'The standard domestic worker contract guarantees at least one rest day every week.',
        noteFil: 'Sa standard contract ng kasambahay, may kahit isang day off kada linggo.',
        kbIds: [...sub, 'hsw_rest'],
      ));
    }
  }

  // Leave
  if (verified.leaveDays != null && current.leaveDays != null && current.leaveDays! < verified.leaveDays!) {
    out.add(Discrepancy(
      field: 'leave',
      titleEn: 'Less paid leave',
      titleFil: 'Mas kaunting bayad na bakasyon',
      before: '${verified.leaveDays} days',
      after: '${current.leaveDays} days',
      severity: Severity.medium,
      noteEn: 'Paid vacation was cut by ${verified.leaveDays! - current.leaveDays!} days a year.',
      noteFil: 'Nabawasan ng ${verified.leaveDays! - current.leaveDays!} araw ang bayad na bakasyon kada taon.',
      kbIds: [...sub, 'hsw_leave'],
    ));
  }

  // Duration
  if (verified.durationMonths != null && current.durationMonths != null && verified.durationMonths != current.durationMonths) {
    out.add(Discrepancy(
      field: 'duration',
      titleEn: 'Contract length changed',
      titleFil: 'Binago ang haba ng kontrata',
      before: _months(verified.durationMonths),
      after: _months(current.durationMonths),
      severity: Severity.medium,
      noteEn: 'A longer contract keeps you tied to this employer longer.',
      noteFil: 'Mas matagal kang nakatali sa employer kapag humaba ang kontrata.',
      kbIds: sub,
    ));
  }

  // Job, employer, worksite
  void textChange(String field, String? a, String? b, String en, String filT, String noteEn, String noteFil) {
    if (a == null || b == null) return;
    final na = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final nb = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (na == nb || na.contains(nb) || nb.contains(na)) return;
    out.add(Discrepancy(
      field: field,
      titleEn: en,
      titleFil: filT,
      before: a,
      after: b,
      severity: Severity.high,
      noteEn: noteEn,
      noteFil: noteFil,
      kbIds: sub,
    ));
  }

  textChange('position', verified.position, current.position, 'Different job', 'Ibang trabaho',
      'You were verified for a different job. Being made to do other work is a common sign of substitution.',
      'Ibang trabaho ang na-verify para sa iyo. Karaniwang senyales ito ng contract substitution.');
  textChange('employer', verified.employer, current.employer, 'Different employer', 'Ibang employer',
      'The employer named here is not the one DMW verified.', 'Hindi ito ang employer na na-verify ng DMW.');
  textChange('worksite', verified.worksite, current.worksite, 'Different worksite', 'Ibang lugar ng trabaho',
      'The place of work differs from your verified contract.', 'Iba ang lugar ng trabaho sa na-verify mong kontrata.');

  // Benefits removed
  void benefitRemoved(String field, bool? a, bool? b, String en, String filT, List<String> ids) {
    if (a == true && b == false) {
      out.add(Discrepancy(
        field: field,
        titleEn: en,
        titleFil: filT,
        before: _yn(a, fil),
        after: _yn(b, fil),
        severity: Severity.high,
        noteEn: 'A benefit in your verified contract is gone.',
        noteFil: 'Nawala ang benepisyong nasa na-verify mong kontrata.',
        kbIds: [...sub, ...ids],
      ));
    }
  }

  benefitRemoved('food', verified.freeFood, current.freeFood, 'Free food removed', 'Tinanggal ang libreng pagkain', const ['hsw_free_board']);
  benefitRemoved('lodging', verified.freeLodging, current.freeLodging, 'Free lodging removed', 'Tinanggal ang libreng tirahan', const ['hsw_free_board']);
  benefitRemoved('airfare', verified.airfare, current.airfare, 'Airfare now charged to you', 'Ikaw na ang magbabayad ng pamasahe', const ['repatriation']);

  // New risky clauses
  if (current.deductionClause && !verified.deductionClause) {
    out.add(Discrepancy(
      field: 'deduction',
      titleEn: 'New salary deduction clause',
      titleFil: 'May bagong kaltas sa sahod',
      before: fil ? 'Wala' : 'None',
      after: fil ? 'Mayroon' : 'Present',
      severity: Severity.medium,
      noteEn: 'Deductions not in your verified contract can quietly lower your pay. Ask what they are for, in writing.',
      noteFil: 'Ang kaltas na wala sa na-verify mong kontrata ay puwedeng magpababa ng sahod mo. Itanong nang nakasulat kung para saan.',
      kbIds: const ['fees_hsw', 'substitution_definition'],
    ));
  }
  if (current.passportHeldClause) {
    out.add(Discrepancy(
      field: 'passport',
      titleEn: 'Employer keeps your passport',
      titleFil: 'Hawak ng employer ang passport mo',
      before: verified.passportHeldClause ? (fil ? 'Mayroon' : 'Present') : (fil ? 'Wala' : 'None'),
      after: fil ? 'Mayroon' : 'Present',
      severity: Severity.high,
      noteEn: 'Holding a worker\'s passport is a major warning sign. Before departure, withholding travel documents for money is illegal recruitment.',
      noteFil: 'Malaking babala ang paghawak sa passport mo. Bago umalis, illegal recruitment ang pagkuha nito kapalit ng pera.',
      kbIds: const ['withholding_documents'],
    ));
  }

  // Standards check on the new contract
  if (current.currency == 'USD' && current.salary != null && _isDomestic(current.position ?? verified.position)) {
    if (current.salary! < 400) {
      out.add(Discrepancy(
        field: 'minimum',
        titleEn: 'Below the old US\$400 floor',
        titleFil: 'Mas mababa sa dating US\$400 na minimum',
        before: 'US\$400–500',
        after: current.salaryLabel,
        severity: Severity.high,
        noteEn: 'Domestic worker pay below US\$400 is below even the pre-2025 DMW minimum.',
        noteFil: 'Mas mababa ito kahit sa dating minimum ng DMW bago 2025.',
        kbIds: const ['hsw_minimum_wage'],
      ));
    } else if (current.salary! < 500) {
      out.add(Discrepancy(
        field: 'minimum',
        titleEn: 'Below the DMW US\$500 standard',
        titleFil: 'Mas mababa sa US\$500 na pamantayan ng DMW',
        before: 'US\$500',
        after: current.salaryLabel,
        severity: Severity.info,
        noteEn: 'DMW set US\$500 as the domestic worker minimum in 2025, with a transition period. Ask the MWO whether it applies to you.',
        noteFil: 'Itinakda ng DMW ang US\$500 noong 2025 na may transition period. Itanong sa MWO kung saklaw ka nito.',
        kbIds: const ['hsw_minimum_wage'],
      ));
    }
  }
  if (current.currency == 'HKD' && current.salary != null && current.salary! < 5220) {
    out.add(Discrepancy(
      field: 'minimum',
      titleEn: 'Below Hong Kong\'s HK\$5,220 minimum',
      titleFil: 'Mas mababa sa HK\$5,220 na minimum ng Hong Kong',
      before: 'HKD 5,220',
      after: current.salaryLabel,
      severity: current.salary! < 5100 ? Severity.high : Severity.medium,
      noteEn: 'Contracts signed from 3 October 2026 must pay at least HK\$5,220 a month.',
      noteFil: 'Ang kontratang pinirmahan mula 3 Oktubre 2026 ay dapat hindi bababa sa HK\$5,220 kada buwan.',
      kbIds: const ['country_hk_wage'],
    ));
  }
  if (current.restHoursPerDay != null && current.restHoursPerDay! < 8 && _isDomestic(current.position ?? verified.position)) {
    out.add(Discrepancy(
      field: 'restStandard',
      titleEn: 'Less than 8 hours of daily rest',
      titleFil: 'Kulang sa 8 oras ang pahinga',
      before: '8 h',
      after: '${current.restHoursPerDay} h',
      severity: Severity.high,
      noteEn: 'The standard domestic worker contract requires at least 8 continuous hours of rest a day.',
      noteFil: 'Sa standard contract ng kasambahay, dapat may hindi bababa sa 8 tuloy-tuloy na oras ng pahinga.',
      kbIds: const ['hsw_rest'],
    ));
  }

  out.sort((a, b) => a.severity.index.compareTo(b.severity.index));
  return out;
}

String diffSummaryForModel(List<Discrepancy> d) =>
    d.where((x) => x.severity != Severity.better).map((x) => '- ${x.titleEn}: was ${x.before}, now ${x.after}').join('\n');
