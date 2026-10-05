import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();

  @override
  List<Object?> get props => [];
}

class LoadBills extends BillingEvent {}

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

  const UpdateBill(this.id, this.request, {this.receipt, this.payment});

  @override
  List<Object?> get props => [id, request, receipt, payment];
}

/// Attaches (or replaces) the tenant's payment image of bill [id].
class UploadPayment extends BillingEvent {
  final int id;
  final PreparedReceipt payment;

  const UploadPayment(this.id, this.payment);

  @override
  List<Object?> get props => [id, payment];
}

/// Removes the payment image of bill [id].
class ClearPayment extends BillingEvent {
  final int id;

  const ClearPayment(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteBill extends BillingEvent {
  final int id;
  final Completer<void> onComplete;

  DeleteBill(this.id, {required this.onComplete});
}
