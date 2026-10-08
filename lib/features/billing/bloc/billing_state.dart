import 'package:equatable/equatable.dart';
import 'package:m18_residences_admin/features/billing/bloc/bill_scope.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BillingInitial extends BillingState {}

class BillingLoading extends BillingState {}

class AddSuccess extends BillingState {}

class UpdateSuccess extends BillingState {}

class DeleteSuccess extends BillingState {}

class BillingLoaded extends BillingState {
  /// Newest first: the bills [coverage] says are loaded (not every bill).
  final List<Bill> bills;
  final List<Room> rooms;
  final List<Tenant> tenants;
  final List<Reading> readings;

  /// The years with bills, newest first (for the year filter).
  final List<int> years;
  final BillCoverage coverage;

  /// More bills for the Billing page's filters are on their way.
  final bool loadingMore;

  BillingLoaded(this.bills, this.rooms, this.tenants, this.readings, {required this.years, required this.coverage, this.loadingMore = false});

  BillingLoaded copyWith({List<Bill>? bills, BillCoverage? coverage, bool? loadingMore}) => BillingLoaded(
    bills ?? this.bills,
    rooms,
    tenants,
    readings,
    years: years,
    coverage: coverage ?? this.coverage,
    loadingMore: loadingMore ?? this.loadingMore,
  );

  @override
  List<Object?> get props => [bills, rooms, tenants, readings, years, coverage, loadingMore];
}

/// Loading the billing data failed; the page shows the error instead of the bills.
class BillingError extends BillingState {
  final String message;
  BillingError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating, updating or deleting a bill failed; the page keeps showing the bills and reports [message].
class BillingActionFailed extends BillingState {
  static int _count = 0;

  final String message;

  /// Makes every failure a new state, so the same failure twice in a row is reported twice.
  final int _id = _count++;

  BillingActionFailed(this.message);

  @override
  List<Object?> get props => [message, _id];
}
