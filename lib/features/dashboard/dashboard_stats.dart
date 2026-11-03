import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Billed and collected (bills with a receipt) totals of one month.
class MonthTotals {
  final DateTime month;
  final int billed;
  final int collected;

  const MonthTotals(this.month, this.billed, this.collected);
}

/// The dashboard's figures, computed in the app from the loaded bills, rooms and tenants (no extra request).
class DashboardStats {
  /// The month the figures are for: the latest bill's month (this month when there are no bills).
  final DateTime month;
  final int billed;
  final int collected;
  final int unpaidCount;
  final int verifyingCount;
  final int paidCount;
  final int occupiedRooms;
  final int roomCount;
  final int activeTenants;

  /// The twelve months up to [month], oldest first.
  final List<MonthTotals> history;

  /// Bills needing the owner: payments to verify first, then unpaid bills past their grace month (posted before the
  /// start of last month); newest first within each.
  final List<Bill> attention;

  /// Unpaid bills still in their grace month, left out of [attention] (tenants often pay a month late).
  final int recentUnpaid;

  const DashboardStats({
    required this.month,
    required this.billed,
    required this.collected,
    required this.unpaidCount,
    required this.verifyingCount,
    required this.paidCount,
    required this.occupiedRooms,
    required this.roomCount,
    required this.activeTenants,
    required this.history,
    required this.attention,
    required this.recentUnpaid,
  });

  int get outstanding => billed - collected;
  int get billCount => unpaidCount + verifyingCount + paidCount;

  factory DashboardStats.from({required List<Bill> bills, required List<Room> rooms, required List<Tenant> tenants, DateTime? now}) {
    final today = now ?? DateTime.now();
    final latest = bills.isEmpty ? today : bills.map((b) => b.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final month = DateTime(latest.year, latest.month);
    bool inMonth(Bill b, DateTime m) => b.createdAt.year == m.year && b.createdAt.month == m.month;

    final thisMonth = bills.where((b) => inMonth(b, month)).toList();
    int count(BillStatus s) => thisMonth.where((b) => b.status == s).length;
    int total(Iterable<Bill> list) => list.fold(0, (sum, b) => sum + b.totalAmount);

    final history = [
      for (var i = 11; i >= 0; i--)
        () {
          final m = DateTime(month.year, month.month - i);
          final ofMonth = bills.where((b) => inMonth(b, m));
          return MonthTotals(m, total(ofMonth), total(ofMonth.where((b) => b.status == BillStatus.paid)));
        }(),
    ];

    final active = tenants.where((t) => t.isActive);
    final occupied = active.map((t) => t.roomId).toSet().intersection(rooms.map((r) => r.id).toSet());

    List<Bill> newestFirst(Iterable<Bill> list) => list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final dueBefore = DateTime(today.year, today.month - 1);
    final unpaid = bills.where((b) => b.status == BillStatus.unpaid);
    final overdue = unpaid.where((b) => b.createdAt.isBefore(dueBefore));

    return DashboardStats(
      month: month,
      billed: total(thisMonth),
      collected: total(thisMonth.where((b) => b.status == BillStatus.paid)),
      unpaidCount: count(BillStatus.unpaid),
      verifyingCount: count(BillStatus.forVerification),
      paidCount: count(BillStatus.paid),
      occupiedRooms: occupied.length,
      roomCount: rooms.length,
      activeTenants: active.length,
      history: history,
      attention: [...newestFirst(bills.where((b) => b.status == BillStatus.forVerification)), ...newestFirst(overdue)],
      recentUnpaid: unpaid.length - overdue.length,
    );
  }
}
