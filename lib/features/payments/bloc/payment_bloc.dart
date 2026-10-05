import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'payment_event.dart';
import 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentApi paymentApi;

  PaymentBloc(this.paymentApi) : super(PaymentInitial()) {
    on<LoadPayments>(_onLoadPayments);
    on<ReplacePayment>(_onReplacePayment);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadPayments(LoadPayments event, Emitter<PaymentState> emit) async {
    emit(PaymentLoading());
    try {
      emit(PaymentLoaded(await paymentApi.list()));
    } catch (e) {
      emit(PaymentError('Failed to load the payment QR codes: ${_reason(e)}'));
    }
  }

  Future<void> _onReplacePayment(ReplacePayment event, Emitter<PaymentState> emit) async {
    try {
      await paymentApi.upload(event.name, event.png);
      add(LoadPayments());
      emit(PaymentReplaced(event.name));
    } catch (e) {
      emit(PaymentActionFailed('Failed to replace the ${event.name} QR code: ${_reason(e)}'));
    }
  }
}
