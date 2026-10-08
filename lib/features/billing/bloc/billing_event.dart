import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:m18_residences_admin/features/billing/bloc/bill_scope.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the last twelve months' bills plus every open one, the years, rooms, tenants and readings.
class LoadBills extends BillingEvent {}

/// Loads the bills [view] needs, unless they are loaded already.
class EnsureBills extends BillingEvent {
  final BillView view;

  const EnsureBills(this.view);

  @override
  List<Object?> get props => [view];
}

class AddBill extends BillingEvent {
  final BillRequest request;

  /// Receipt picked (and converted) in the form; uploaded to the new bill right after it is created.
  final PreparedReceipt? receipt;

  /// The tenant's payment image picked in the form; uploaded after the bill is created.
  final PreparedReceipt? payment;

  const AddBill(this.request, {this.receipt, this.payment});

  @override
  List<Object?> get props => [request, receipt, payment];
}

class UpdateBill extends BillingEvent {
  final int id;
  final BillRequest request;

  /// Receipt picked (and converted) in the form; when set, the update is sent together with the file upload.
  final PreparedReceipt? receipt;

  /// The tenant's payment image picked in the form; uploaded after the update.
  final PreparedReceipt? payment;

  /// Remove the bill's payment image after the update (Remove in the form, nothing new picked).
  final bool removePayment;

  const UpdateBill(this.id, this.request, {this.receipt, this.payment, this.removePayment = false});

  @override
  List<Object?> get props => [id, request, receipt, payment, removePayment];
}

class DeleteBill extends BillingEvent {
  final int id;
  final Completer<void> onComplete;

  DeleteBill(this.id, {required this.onComplete});
}
