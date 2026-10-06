import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'billing_event.dart';
import 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final ReadingApi readingApi;
  final RoomApi roomApi;
  final TenantApi tenantApi;
  final BillApi billApi;

  BillingBloc({required this.readingApi, required this.roomApi, required this.tenantApi, required this.billApi}) : super(BillingInitial()) {
    on<LoadBills>(_onLoadBills);
    on<AddBill>(_onAddBill);
    on<UpdateBill>(_onUpdateBill);
    on<DeleteBill>(_onDeleteBill);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadBills(LoadBills event, Emitter<BillingState> emit) async {
    emit(BillingLoading());
    try {
      // Independent requests, sent together; the first failure is reported.
      final data = await Future.wait<Object>([billApi.list(), roomApi.list(), tenantApi.list(), readingApi.list()]);
      emit(BillingLoaded(data[0] as List<Bill>, data[1] as List<Room>, data[2] as List<Tenant>, data[3] as List<Reading>));
    } catch (e) {
      emit(BillingError('Failed to load billing data: ${_reason(e)}'));
    }
  }

  Future<void> _onAddBill(AddBill event, Emitter<BillingState> emit) async {
    final Bill created;
    try {
      created = await billApi.create(event.request);
    } catch (e) {
      emit(BillingActionFailed('Failed to create bill: ${_reason(e)}'));
      return;
    }
    final receipt = event.receipt;
    if (receipt != null) {
      try {
        await billApi.uploadReceipt(created.id, event.request, bytes: receipt.bytes, filename: receipt.filename, contentType: receipt.contentType);
      } catch (e) {
        add(LoadBills());
        emit(BillingActionFailed('Bill created, but the receipt upload failed: ${_reason(e)}'));
        return;
      }
    }
    if (!await _uploadPayment(created.id, event.payment, emit, 'Bill created')) return;
    add(LoadBills());
    emit(AddSuccess());
  }

  /// Uploads [payment] (if any) to bill [id] after the bill itself was saved; on failure reloads, reports
  /// "[saved], but the payment upload failed" and returns false.
  Future<bool> _uploadPayment(int id, PreparedReceipt? payment, Emitter<BillingState> emit, String saved) async {
    if (payment == null) return true;
    try {
      await billApi.uploadPayment(id, bytes: payment.bytes, filename: payment.filename, contentType: payment.contentType);
      return true;
    } catch (e) {
      add(LoadBills());
      emit(BillingActionFailed('$saved, but the payment upload failed: ${_reason(e)}'));
      return false;
    }
  }

  Future<void> _onUpdateBill(UpdateBill event, Emitter<BillingState> emit) async {
    try {
      final receipt = event.receipt;
      if (receipt == null) {
        await billApi.update(event.id, event.request);
      } else {
        await billApi.uploadReceipt(event.id, event.request, bytes: receipt.bytes, filename: receipt.filename, contentType: receipt.contentType);
      }
    } catch (e) {
      emit(BillingActionFailed('Failed to update bill: ${_reason(e)}'));
      return;
    }
    if (!await _uploadPayment(event.id, event.payment, emit, 'Bill updated')) return;
    if (event.removePayment) {
      try {
        await billApi.clearPayment(event.id);
      } catch (e) {
        add(LoadBills());
        emit(BillingActionFailed('Bill updated, but removing the payment failed: ${_reason(e)}'));
        return;
      }
    }
    add(LoadBills());
    emit(UpdateSuccess());
  }

  Future<void> _onDeleteBill(DeleteBill event, Emitter<BillingState> emit) async {
    try {
      await billApi.delete(event.id);
      event.onComplete.complete();
      add(LoadBills());
      emit(DeleteSuccess());
    } catch (e) {
      event.onComplete.completeError(e);
      emit(BillingActionFailed('Failed to delete bill: ${_reason(e)}'));
    }
  }
}
