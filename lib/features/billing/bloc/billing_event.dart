import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:m18_residences_admin/features/billing/receipt_converter.dart';
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

  const AddBill(this.request, {this.receipt});

  @override
  List<Object?> get props => [request, receipt];
}

class UpdateBill extends BillingEvent {
  final int id;
  final BillRequest request;

  /// Receipt picked (and converted) in the form; when set, the update is sent together with the file upload.
  final PreparedReceipt? receipt;

  const UpdateBill(this.id, this.request, {this.receipt});

  @override
  List<Object?> get props => [id, request, receipt];
}

class DeleteBill extends BillingEvent {
  final int id;
  final Completer<void> onComplete;

  DeleteBill(this.id, {required this.onComplete});
}
