import 'package:equatable/equatable.dart';
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

/// A payment image was attached or removed; [message] says which.
class PaymentSuccess extends BillingState {
  final String message;

  PaymentSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class BillingLoaded extends BillingState {
  final List<Bill> bills;
  final List<Room> rooms;
  final List<Tenant> tenants;
  final List<Reading> readings;

  BillingLoaded(this.bills, this.rooms, this.tenants, this.readings);

  @override
  List<Object?> get props => [bills, rooms, tenants, readings];
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
