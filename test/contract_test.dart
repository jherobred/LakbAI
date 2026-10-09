import 'package:flutter_test/flutter_test.dart';
import 'package:kontrata/contract/contract.dart';

// Text as ML Kit returns it for the bundled sample contracts (line breaks included).
const verified = '''
SAMPLE ONLY - NOT A REAL CONTRACT - FOR DEMONSTRATION
STANDARD EMPLOYMENT CONTRACT
Filipino Household Service Workers
Employer's Name: Abdullah Al-Rashid
Site of Employment: Riyadh, Kingdom of Saudi Arabia
Worker: Maria Dela Cruz (sample)
Position: Household Service Worker
1. Contract Duration. The period of employment is two (2) years commencing from the worker's
departure from the Philippines.
2. Basic Monthly Salary: USD 500.00 payable at the end of each month.
3. Hours of Rest. The worker shall be entitled to at least eight (8) continuous hours of rest per
day. Working hours: 10 hours per day.
4. Rest Day. The worker shall have one (1) rest day per week.
5. Vacation Leave. The worker shall be entitled to fifteen (15) calendar days of vacation leave
with full pay for every year of service.
6. Food and Lodging. The employer shall provide free food and free suitable living quarters.
7. Transportation. Free round-trip airfare shall be borne by the employer.
8. Travel Documents. The worker shall keep his or her own passport and travel documents at all
times.
''';

const substituted = '''
SAMPLE ONLY - NOT A REAL CONTRACT - FOR DEMONSTRATION
EMPLOYMENT AGREEMENT
Domestic Worker
Employer's Name: Abdullah Al-Rashid
Site of Employment: Riyadh, Kingdom of Saudi Arabia
Worker: Maria Dela Cruz (sample)
Position: Domestic Helper and Farm Worker
1. Contract Duration. The period of employment is three (3) years commencing from the date
of arrival.
2. Basic Monthly Salary: USD 400.00 payable at the end of each month.
3. Hours of Rest. The worker shall be entitled to at least six (6) continuous hours of rest per
day. Working hours: 14 hours per day.
4. Rest Day. The worker shall have one (1) rest day per month.
5. Vacation Leave. The worker shall be entitled to seven (7) calendar days of vacation leave
with full pay for every year of service.
6. Food and Lodging. The employer shall provide free suitable living quarters. The worker
shall pay for own food.
7. Transportation. Return airfare shall be borne by the worker.
8. Travel Documents. The employer shall keep the worker's passport for safekeeping.
9. Placement costs shall be deducted from the worker's salary in equal monthly amounts.
''';

void main() {
  test('reads the verified sample contract', () {
    final t = extractTerms(verified);
    expect(t.salary, 500);
    expect(t.currency, 'USD');
    expect(t.restHoursPerDay, 8);
    expect(t.workHoursPerDay, 10);
    expect(t.restDays, 1);
    expect(t.restPeriod, 'week');
    expect(t.leaveDays, 15);
    expect(t.durationMonths, 24);
    expect(t.position, 'Household Service Worker');
    expect(t.employer, 'Abdullah Al-Rashid');
    expect(t.freeFood, true);
    expect(t.freeLodging, true);
    expect(t.airfare, true);
    expect(t.passportHeldClause, false);
    expect(t.deductionClause, false);
  });

  test('finds every substituted clause', () {
    final v = extractTerms(verified);
    final n = extractTerms(substituted);
    expect(n.salary, 400);
    expect(n.restHoursPerDay, 6);
    expect(n.workHoursPerDay, 14);
    expect(n.restPeriod, 'month');
    expect(n.leaveDays, 7);
    expect(n.durationMonths, 36);
    expect(n.freeFood, false);
    expect(n.airfare, false);
    expect(n.passportHeldClause, true);
    expect(n.deductionClause, true);

    final d = compareContracts(v, n, fil: false);
    final fields = d.map((x) => x.field).toSet();
    expect(fields, containsAll(['salary', 'restHours', 'workHours', 'restDays', 'leave', 'duration', 'position', 'food', 'airfare', 'deduction', 'passport']));
    expect(d.first.severity, Severity.high);
  });

  test('identical contracts show no changes against the worker', () {
    final d = compareContracts(extractTerms(verified), extractTerms(verified), fil: false);
    expect(d.where((x) => x.severity == Severity.high || x.severity == Severity.medium), isEmpty);
  });
}
