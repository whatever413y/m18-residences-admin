import 'package:flutter_test/flutter_test.dart';
import 'package:m18_residences_admin/features/dashboard/dashboard_stats.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

Bill bill(int id, {required int tenant, required DateTime at, required int total, String? payment, String? receipt}) => Bill(
  id: id,
  tenantId: tenant,
  readingId: id,
  roomCharges: total,
  electricCharges: 0,
  totalAmount: total,
  paid: receipt != null,
  createdAt: at,
  paymentUrl: payment,
  receiptUrl: receipt,
);

void main() {
  final rooms = [
    const Room(id: 1, name: 'Room 1', rent: 5000),
    const Room(id: 2, name: 'Room 2', rent: 5000),
    const Room(id: 3, name: 'Room 3', rent: 5000),
  ];
  final tenants = [
    Tenant(id: 1, roomId: 1, name: 'ALPHA', joinDate: DateTime(2025), isActive: true),
    Tenant(id: 2, roomId: 1, name: 'BRAVO', joinDate: DateTime(2025), isActive: true), // shares room 1
    Tenant(id: 3, roomId: 2, name: 'CHARLIE', joinDate: DateTime(2025), isActive: false),
  ];
  final bills = [
    bill(1, tenant: 1, at: DateTime(2026, 9, 1), total: 1000, receipt: 'r1'),
    bill(2, tenant: 1, at: DateTime(2026, 10, 1), total: 2000, payment: 'p2'),
    bill(3, tenant: 2, at: DateTime(2026, 10, 2), total: 3000),
    bill(4, tenant: 2, at: DateTime(2026, 10, 3), total: 4000, payment: 'p4', receipt: 'r4'),
    bill(5, tenant: 3, at: DateTime(2025, 10, 1), total: 500), // a year ago: outside the 12 months
  ];

  test('figures are for the latest bill month', () {
    final stats = DashboardStats.from(bills: bills, rooms: rooms, tenants: tenants);
    expect(stats.month, DateTime(2026, 10));
    expect(stats.billed, 9000);
    expect(stats.collected, 4000);
    expect(stats.outstanding, 5000);
    expect((stats.unpaidCount, stats.verifyingCount, stats.paidCount), (1, 1, 1));
  });

  test('occupancy counts rooms with an active tenant once', () {
    final stats = DashboardStats.from(bills: bills, rooms: rooms, tenants: tenants);
    expect(stats.occupiedRooms, 1);
    expect(stats.roomCount, 3);
    expect(stats.activeTenants, 2);
  });

  test('history is the twelve months up to the latest, oldest first', () {
    final history = DashboardStats.from(bills: bills, rooms: rooms, tenants: tenants).history;
    expect(history, hasLength(12));
    expect(history.first.month, DateTime(2025, 11));
    expect(history.last.month, DateTime(2026, 10));
    expect((history[10].billed, history[10].collected), (1000, 1000));
    expect((history[11].billed, history[11].collected), (9000, 4000));
  });

  test('attention lists payments to verify first, then unpaid bills, newest first', () {
    final attention = DashboardStats.from(bills: bills, rooms: rooms, tenants: tenants).attention;
    expect(attention.map((b) => b.id), [2, 3, 5]);
  });

  test('no bills: this month, all zero', () {
    final stats = DashboardStats.from(bills: const [], rooms: rooms, tenants: tenants, now: DateTime(2026, 10, 6));
    expect(stats.month, DateTime(2026, 10));
    expect(stats.billed, 0);
    expect(stats.attention, isEmpty);
  });
}
