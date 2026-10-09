import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../contract/contract.dart';

/// A photo of a contract page, with a fingerprint that shows it was not edited later.
class EvidencePage {
  EvidencePage({required this.path, required this.sha256, required this.capturedAt, required this.role});

  final String path;
  final String sha256;
  final DateTime capturedAt;
  final String role; // 'verified' | 'new' | 'other'

  Map<String, dynamic> toJson() => {'path': path, 'sha256': sha256, 'capturedAt': capturedAt.toIso8601String(), 'role': role};
  factory EvidencePage.fromJson(Map<String, dynamic> j) => EvidencePage(
        path: j['path'] as String,
        sha256: j['sha256'] as String,
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        role: j['role'] as String,
      );
}

enum CaseKind { substitution, recruiter }

/// Everything about one problem the worker wants to keep a record of.
class CaseFile {
  CaseFile({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.verified,
    this.current,
    this.discrepancies = const [],
    this.pages = const [],
    this.statement = '',
    this.workerName = '',
    this.agency = '',
    this.employer = '',
    this.country = '',
    this.incidentDate = '',
    this.incidentPlace = '',
    this.redFlags = const [],
    this.level = 1,
  });

  final String id;
  final CaseKind kind;
  final DateTime createdAt;
  ContractTerms? verified;
  ContractTerms? current;
  List<Discrepancy> discrepancies;
  List<EvidencePage> pages;
  String statement;
  String workerName;
  String agency;
  String employer;
  String country;
  String incidentDate;
  String incidentPlace;
  List<String> redFlags;
  int level;

  int get worseCount => discrepancies.where((d) => d.severity == Severity.high || d.severity == Severity.medium).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'verified': verified?.toJson(),
        'current': current?.toJson(),
        'discrepancies': discrepancies.map((d) => d.toJson()).toList(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'statement': statement,
        'workerName': workerName,
        'agency': agency,
        'employer': employer,
        'country': country,
        'incidentDate': incidentDate,
        'incidentPlace': incidentPlace,
        'redFlags': redFlags,
        'level': level,
      };

  factory CaseFile.fromJson(Map<String, dynamic> j) => CaseFile(
        id: j['id'] as String,
        kind: CaseKind.values.byName(j['kind'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
        verified: j['verified'] == null ? null : ContractTerms.fromJson(j['verified'] as Map<String, dynamic>),
        current: j['current'] == null ? null : ContractTerms.fromJson(j['current'] as Map<String, dynamic>),
        discrepancies: (j['discrepancies'] as List? ?? []).map((d) => Discrepancy.fromJson(d as Map<String, dynamic>)).toList(),
        pages: (j['pages'] as List? ?? []).map((p) => EvidencePage.fromJson(p as Map<String, dynamic>)).toList(),
        statement: j['statement'] as String? ?? '',
        workerName: j['workerName'] as String? ?? '',
        agency: j['agency'] as String? ?? '',
        employer: j['employer'] as String? ?? '',
        country: j['country'] as String? ?? '',
        incidentDate: j['incidentDate'] as String? ?? '',
        incidentPlace: j['incidentPlace'] as String? ?? '',
        redFlags: (j['redFlags'] as List? ?? []).cast<String>(),
        level: j['level'] as int? ?? 1,
      );
}

/// Stores cases as JSON files in the app's private folder.
class CaseRepository {
  CaseRepository._();
  static final instance = CaseRepository._();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/cases');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> evidenceDir(String caseId) async {
    final d = Directory('${(await _dir()).path}/$caseId');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String newId() => DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();

  /// Copies a captured photo into the case folder and fingerprints it.
  Future<EvidencePage> addEvidence(String caseId, String sourcePath, String role) async {
    final dir = await evidenceDir(caseId);
    final bytes = await File(sourcePath).readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final dest = File('${dir.path}/${role}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await dest.writeAsBytes(bytes, flush: true);
    return EvidencePage(path: dest.path, sha256: hash, capturedAt: DateTime.now(), role: role);
  }

  Future<void> save(CaseFile c) async {
    final f = File('${(await _dir()).path}/${c.id}.json');
    await f.writeAsString(jsonEncode(c.toJson()), flush: true);
  }

  Future<List<CaseFile>> list() async {
    final d = await _dir();
    final out = <CaseFile>[];
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          out.add(CaseFile.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> delete(CaseFile c) async {
    final d = await _dir();
    final f = File('${d.path}/${c.id}.json');
    if (await f.exists()) await f.delete();
    final ev = Directory('${d.path}/${c.id}');
    if (await ev.exists()) await ev.delete(recursive: true);
  }

  Future<void> wipeAll() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
  }
}
