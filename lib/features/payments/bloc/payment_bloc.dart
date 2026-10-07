import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'payment_event.dart';
import 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentApi paymentApi;

  PaymentBloc(this.paymentApi) : super(PaymentInitial()) {
    on<LoadPayments>(_onLoadPayments);
    on<CreatePaymentMethod>(_onCreate);
    on<UpdatePaymentMethod>(_onUpdate);
    on<DeletePaymentMethod>(_onDelete);
    on<UploadPaymentImage>(_onUploadImage);
    on<RemovePaymentImage>(_onRemoveImage);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadPayments(LoadPayments event, Emitter<PaymentState> emit) async {
    emit(PaymentLoading());
    try {
      emit(PaymentLoaded(await paymentApi.list()));
    } catch (e) {
      emit(PaymentError('Failed to load the payment methods: ${_reason(e)}'));
    }
  }

  Future<void> _onCreate(CreatePaymentMethod event, Emitter<PaymentState> emit) async {
    final name = event.request.name;
    final PaymentMethod created;
    try {
      created = await paymentApi.create(event.request);
    } catch (e) {
      emit(PaymentActionFailed('Failed to add $name: ${_reason(e)}'));
      return;
    }
    final png = event.png;
    if (png != null) {
      try {
        await paymentApi.uploadImage(created.id, png);
      } catch (e) {
        add(LoadPayments());
        emit(PaymentActionFailed('$name was added, but its QR code was not: ${_reason(e)}'));
        return;
      }
    }
    add(LoadPayments());
    emit(PaymentActionSucceeded('$name added'));
  }

  Future<void> _onUpdate(UpdatePaymentMethod event, Emitter<PaymentState> emit) async {
    try {
      final updated = await paymentApi.update(event.id, event.request);
      add(LoadPayments());
      emit(PaymentActionSucceeded('${updated.name} saved'));
    } catch (e) {
      emit(PaymentActionFailed('Failed to save ${event.request.name}: ${_reason(e)}'));
    }
  }

  Future<void> _onDelete(DeletePaymentMethod event, Emitter<PaymentState> emit) async {
    try {
      await paymentApi.delete(event.method.id);
      event.onComplete.complete();
      add(LoadPayments());
      emit(PaymentActionSucceeded('${event.method.name} deleted'));
    } catch (e) {
      event.onComplete.completeError(e);
      emit(PaymentActionFailed('Failed to delete ${event.method.name}: ${_reason(e)}'));
    }
  }

  Future<void> _onUploadImage(UploadPaymentImage event, Emitter<PaymentState> emit) async {
    final name = event.method.name;
    try {
      await paymentApi.uploadImage(event.method.id, event.png);
      add(LoadPayments());
      emit(PaymentActionSucceeded(event.method.hasImage ? '$name QR code replaced' : '$name QR code uploaded'));
    } catch (e) {
      emit(PaymentActionFailed('Failed to upload the $name QR code: ${_reason(e)}'));
    }
  }

  Future<void> _onRemoveImage(RemovePaymentImage event, Emitter<PaymentState> emit) async {
    final name = event.method.name;
    try {
      await paymentApi.deleteImage(event.method.id);
      event.onComplete.complete();
      add(LoadPayments());
      emit(PaymentActionSucceeded('$name QR code removed'));
    } catch (e) {
      event.onComplete.completeError(e);
      emit(PaymentActionFailed('Failed to remove the $name QR code: ${_reason(e)}'));
    }
  }
}
