import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class PaymentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentLoaded extends PaymentState {
  final List<PaymentImage> images;

  PaymentLoaded(this.images);

  @override
  List<Object?> get props => [images];
}

/// Loading the payment images failed; the page shows the error instead of them.
class PaymentError extends PaymentState {
  final String message;

  PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentReplaced extends PaymentState {
  final String name;

  PaymentReplaced(this.name);

  @override
  List<Object?> get props => [name];
}

/// Replacing a payment image failed; the page keeps showing the images and reports [message].
class PaymentActionFailed extends PaymentState {
  static int _count = 0;

  final String message;

  /// Makes every failure a new state, so the same failure twice in a row is reported twice.
  final int _id = _count++;

  PaymentActionFailed(this.message);

  @override
  List<Object?> get props => [message, _id];
}
