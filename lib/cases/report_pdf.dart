import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../contract/contract.dart';
import '../knowledge/kb.dart';
import 'cases.dart';

/// Builds a formal, printable incident report entirely on the phone.
class ReportPdf {
  static const _navy = PdfColor.fromInt(0xFF0B1736);
  static const _blue = PdfColor.fromInt(0xFF1A56DB);
  static const _soft = PdfColor.fromInt(0xFF4A5878);
  static const _line = PdfColor.fromInt(0xFFD5DEF0);
  static const _tint = PdfColor.fromInt(0xFFEAF0FD);
  static const _red = PdfColor.fromInt(0xFFE11D48);
  static const _amber = PdfColor.fromInt(0xFFD97706);
  static const _green = PdfColor.fromInt(0xFF16A34A);

  /// The built-in PDF fonts cover Latin-1 only; keep the file readable everywhere.
  static String s(String v) {
    final t = v.replaceAll('₱', 'PHP ').replaceAll('’', "'").replaceAll('‘', "'").replaceAll('“', '"').replaceAll('”', '"').replaceAll('–', '-').replaceAll('—', '-').replaceAll('•', '-');
    return String.fromCharCodes(t.runes.map((r) => r < 256 ? r : 63));
  }

  static Future<File> build(CaseFile c, {required bool fil}) async {
    final doc = pw.Document(title: 'Kontrata incident report ${c.id}', author: 'Kontrata (on-device)');
    final kb = KnowledgeBase.instance;
    final lawIds = <String>{
      for (final d in c.discrepancies) ...d.kbIds,
      if (c.kind == CaseKind.recruiter) ...['recruiter_red_flags', 'criminal_case', 'hotline_1343'],
      'agency_joint_liability',
      'deadlines',
      'evidence_rules',
    };
    final laws = lawIds.map(kb.byId).whereType<KbEntry>().toList();
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final title = c.kind == CaseKind.substitution
        ? (fil ? 'Ulat ng Insidente: Pagpapalit ng Kontrata' : 'Incident Report: Contract Substitution')
        : (fil ? 'Ulat ng Insidente: Illegal Recruitment / Mapanlinlang na Handler' : 'Incident Report: Illegal Recruitment / Abusive Handler');

    pw.Widget h(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(s(text), style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _blue)),
        );
    pw.Widget p(String text, {double size = 10, PdfColor color = _navy}) =>
        pw.Text(s(text), style: pw.TextStyle(fontSize: size, color: color, lineSpacing: 2));
    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 120, child: pw.Text(s(k), style: const pw.TextStyle(fontSize: 9.5, color: _soft))),
            pw.Expanded(child: pw.Text(s(v.isEmpty ? (fil ? 'Hindi inilagay' : 'Not provided') : v), style: const pw.TextStyle(fontSize: 10, color: _navy))),
          ]),
        );

    PdfColor sevColor(Severity sv) => switch (sv) {
          Severity.high => _red,
          Severity.medium => _amber,
          Severity.info => _blue,
          Severity.better => _green,
        };

    final images = <pw.MemoryImage>[];
    for (final pg in c.pages) {
      try {
        final Uint8List bytes = await File(pg.path).readAsBytes();
        images.add(pw.MemoryImage(bytes));
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text(s('Kontrata - ${c.id}'), style: const pw.TextStyle(fontSize: 8, color: _soft)),
        footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(s(fil ? 'Ginawa sa phone ng manggagawa gamit ang Kontrata. Hindi ito legal na payo.' : "Prepared on the worker's phone with Kontrata. Not legal advice."),
              style: const pw.TextStyle(fontSize: 7.5, color: _soft)),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _soft)),
        ]),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('KONTRATA', style: pw.TextStyle(fontSize: 9, color: PdfColors.white, letterSpacing: 2, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(s(title), style: pw.TextStyle(fontSize: 17, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(s('Case ${c.id}  |  ${fil ? 'Ginawa' : 'Generated'} ${fmt(now)}  |  ${fil ? 'Unang naitala' : 'First recorded'} ${fmt(c.createdAt)}'),
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
            ]),
          ),
          h(fil ? '1. Buod' : '1. Summary'),
          p(c.kind == CaseKind.substitution
              ? (fil
                  ? 'Ikinumpara ang kontratang na-verify ng DMW sa kontratang ibinigay sa manggagawa. ${c.worseCount} pagbabago ang nakasama sa manggagawa.'
                  : 'The DMW-verified contract was compared with the contract given to the worker. ${c.worseCount} change(s) were found that disadvantage the worker.')
              : (fil
                  ? 'Iniulat ng manggagawa ang mga senyales ng illegal recruitment o mapang-abusong handler (${c.redFlags.length}).'
                  : 'The worker reported ${c.redFlags.length} warning sign(s) of illegal recruitment or an abusive handler.')),
          h(fil ? '2. Mga partido' : '2. Parties'),
          kv(fil ? 'Manggagawa' : 'Worker', c.workerName),
          kv(fil ? 'Ahensya / recruiter' : 'Agency / recruiter', c.agency),
          kv('Employer', c.employer),
          kv(fil ? 'Bansa / lugar' : 'Country / worksite', c.country),
          kv(fil ? 'Petsa ng insidente' : 'Date of incident', c.incidentDate),
          kv(fil ? 'Lugar ng insidente' : 'Place of incident', c.incidentPlace),
          if (c.kind == CaseKind.substitution && c.discrepancies.isNotEmpty) ...[
            h(fil ? '3. Mga binago sa kontrata' : '3. What changed'),
            pw.Table(
              border: pw.TableBorder.all(color: _line, width: 0.6),
              columnWidths: const {0: pw.FlexColumnWidth(2.2), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5), 3: pw.FlexColumnWidth(0.9)},
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _tint),
                  children: [
                    for (final t in [fil ? 'Termino' : 'Term', fil ? 'Na-verify ng DMW' : 'DMW-verified', fil ? 'Bagong kontrata' : 'New contract', fil ? 'Epekto' : 'Effect'])
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s(t), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                for (final d in c.discrepancies)
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s(d.title(fil)), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s(d.before), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s(d.after), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        s(switch (d.severity) {
                          Severity.high => fil ? 'Malubha' : 'Serious',
                          Severity.medium => fil ? 'Babala' : 'Warning',
                          Severity.info => fil ? 'Tingnan' : 'Check',
                          Severity.better => fil ? 'Mas mabuti' : 'Better',
                        }),
                        style: pw.TextStyle(fontSize: 9, color: sevColor(d.severity), fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ]),
              ],
            ),
          ],
          if (c.kind == CaseKind.recruiter && c.redFlags.isNotEmpty) ...[
            h(fil ? '3. Mga senyales na iniulat' : '3. Warning signs reported'),
            for (final f in c.redFlags) pw.Bullet(text: s(f), style: const pw.TextStyle(fontSize: 10)),
          ],
          h(fil ? '4. Salaysay ng manggagawa' : "4. Worker's statement"),
          p(c.statement.isEmpty ? (fil ? '(Walang salaysay na inilagay.)' : '(No statement entered.)') : c.statement),
          h(fil ? '5. Ebidensya' : '5. Evidence'),
          if (c.pages.isEmpty) p(fil ? 'Walang litratong nakalakip.' : 'No photos attached.'),
          for (final pg in c.pages)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                s('${pg.role == 'verified' ? (fil ? 'Na-verify na kontrata' : 'Verified contract') : pg.role == 'new' ? (fil ? 'Bagong kontrata' : 'New contract') : (fil ? 'Iba pa' : 'Other')}  |  ${fmt(pg.capturedAt)}  |  SHA-256 ${pg.sha256}'),
                style: const pw.TextStyle(fontSize: 7.5, color: _soft),
              ),
            ),
          p(fil
              ? 'Ang SHA-256 ay "fingerprint" ng bawat litrato na ginawa noong kinuha ito. Kapag binago ang litrato, magbabago rin ang fingerprint.'
              : 'Each SHA-256 value is a fingerprint taken when the photo was captured. If a photo is altered, its fingerprint changes.',
              size: 8.5, color: _soft),
          h(fil ? '6. Batayang legal' : '6. Legal basis'),
          for (final l in laws)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: s('${l.title(fil)}. '), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy)),
                  pw.TextSpan(text: s('${l.sourceLabel}.'), style: const pw.TextStyle(fontSize: 9, color: _soft)),
                ]),
              ),
            ),
          h(fil ? '7. Saan ito puwedeng isampa' : '7. Where this can be filed'),
          pw.Bullet(text: s(fil ? 'Abroad: Migrant Workers Office (MWO) sa embahada o konsulado ng Pilipinas.' : 'Abroad: Migrant Workers Office (MWO) at the Philippine embassy or consulate.'), style: const pw.TextStyle(fontSize: 9.5)),
          pw.Bullet(text: s(fil ? 'Pagkakaiba sa sahod at danyos: SEnA (30 araw), saka Labor Arbiter ng NLRC, laban sa ahensya at employer.' : 'Pay differences and damages: SEnA (30 days), then an NLRC Labor Arbiter, against the agency and employer.'), style: const pw.TextStyle(fontSize: 9.5)),
          pw.Bullet(text: s(fil ? 'Paglabag ng ahensya: DMW Adjudication Office.' : 'Agency violations: DMW Adjudication Office.'), style: const pw.TextStyle(fontSize: 9.5)),
          pw.Bullet(text: s(fil ? 'Illegal recruitment o trafficking: DMW, NBI, piskal, o 1343 Actionline.' : 'Illegal recruitment or trafficking: DMW, NBI, prosecutor, or the 1343 Actionline.'), style: const pw.TextStyle(fontSize: 9.5)),
          pw.Bullet(text: s(fil ? 'Taning: 3 taon para sa paghabol ng pera (Labor Code Art. 306).' : 'Deadline: 3 years for money claims (Labor Code Art. 306).'), style: const pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(height: 22),
          pw.Text(s(fil ? 'PATUNAY' : 'ATTESTATION'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          p(fil
              ? 'Pinatutunayan kong totoo at tama ang nakasaad dito ayon sa aking personal na kaalaman.'
              : 'I certify that the statements above are true and correct based on my personal knowledge.'),
          pw.SizedBox(height: 34),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(height: 0.8, color: _navy),
              pw.SizedBox(height: 3),
              pw.Text(s(fil ? 'Lagda at pangalan ng manggagawa' : 'Signature over printed name of worker'), style: const pw.TextStyle(fontSize: 8.5, color: _soft)),
            ])),
            pw.SizedBox(width: 30),
            pw.SizedBox(width: 140, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(height: 0.8, color: _navy),
              pw.SizedBox(height: 3),
              pw.Text(s(fil ? 'Petsa' : 'Date'), style: const pw.TextStyle(fontSize: 8.5, color: _soft)),
            ])),
          ]),
          pw.SizedBox(height: 18),
          p(fil
              ? 'SUBSCRIBED AND SWORN to before me this ___ day of __________, 20__, at ______________. (Para sa MWO, DMW o notaryo.)'
              : 'SUBSCRIBED AND SWORN to before me this ___ day of __________, 20__, at ______________. (For the MWO, DMW or a notary.)',
              size: 8.5, color: _soft),
        ],
      ),
    );

    for (final img in images) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => pw.Column(children: [
            pw.Text(s(fil ? 'Kalakip: litrato ng kontrata' : 'Annex: contract photo'), style: const pw.TextStyle(fontSize: 9, color: _soft)),
            pw.SizedBox(height: 8),
            pw.Expanded(child: pw.Image(img, fit: pw.BoxFit.contain)),
          ]),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Kontrata-report-${c.id}.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }
}
