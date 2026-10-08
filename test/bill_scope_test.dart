import 'package:flutter_test/flutter_test.dart';
import 'package:m18_residences_admin/features/billing/bloc/bill_scope.dart';

void main() {
  test('the first load reaches back twelve months, a day early', () {
    expect(BillCoverage.sinceFor(DateTime(2026, 10, 8)), DateTime(2025, 10, 31));
    expect(BillCoverage.sinceFor(DateTime(2026, 1, 15)), DateTime(2025, 1, 31));
  });

  test('the first load covers the years starting after it, nothing else', () {
    final first = BillCoverage(since: BillCoverage.sinceFor(DateTime(2026, 10, 8)));
    expect(first.covers(const BillView(year: 2026)), isTrue);
    expect(first.covers(const BillView(year: 2026, tenantId: 3)), isTrue);
    expect(first.covers(const BillView(year: 2025)), isFalse);
    expect(first.covers(const BillView()), isFalse, reason: 'All Years');
    expect(first.covers(const BillView(tenantId: 3)), isFalse, reason: 'a tenant over all years');
  });

  test('each fetch adds what it loaded', () {
    var coverage = BillCoverage(since: DateTime(2025, 10, 31));
    coverage = coverage.including(const BillView(year: 2024, tenantId: 3));
    expect(coverage.covers(const BillView(year: 2024)), isTrue);
    expect(coverage.covers(const BillView(tenantId: 3)), isFalse);

    coverage = coverage.including(const BillView(tenantId: 3));
    expect(coverage.covers(const BillView(tenantId: 3)), isTrue);
    expect(coverage.covers(const BillView(tenantId: 4)), isFalse);

    coverage = coverage.including(const BillView(roomId: 2));
    expect(coverage.covers(const BillView(roomId: 2)), isTrue);

    coverage = coverage.including(const BillView());
    expect(coverage.covers(const BillView(year: 1999, tenantId: 9)), isTrue);
  });

  test('a fetch sends one filter: the year, else the tenant, else the room', () {
    final byYear = BillQuery.of(const BillView(year: 2024, tenantId: 3, roomId: 2));
    expect((byYear.year, byYear.tenantId, byYear.roomId), (2024, null, null));
    final byTenant = BillQuery.of(const BillView(tenantId: 3, roomId: 2));
    expect((byTenant.year, byTenant.tenantId, byTenant.roomId), (null, 3, null));
    final all = BillQuery.of(const BillView());
    expect((all.year, all.tenantId, all.roomId), (null, null, null));
  });
}
