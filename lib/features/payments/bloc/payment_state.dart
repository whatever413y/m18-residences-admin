import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class PaymentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentLoaded extends PaymentState {
  final List<PaymentMethod> methods;

  PaymentLoaded(this.methods);

  @override
  List<Object?> get props => [methods];
}

/// Loading the payment methods failed; the page shows the error instead of them.
class PaymentError extends PaymentState {
  final String message;

  PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Every action result is a new state, so the same result twice in a row is reported twice.
abstract class _PaymentActionResult extends PaymentState {
  static int _count = 0;

  final String message;
  final int _id = _count++;

  _PaymentActionResult(this.message);

  @override
  List<Object?> get props => [message, _id];
}

/// An action succeeded; the page reports [message] (e.g. "GCash QR code replaced").
class PaymentActionSucceeded extends _PaymentActionResult {
  PaymentActionSucceeded(super.message);
}

/// An action failed; the page keeps showing the methods and reports [message].
class PaymentActionFailed extends _PaymentActionResult {
  PaymentActionFailed(super.message);
}
