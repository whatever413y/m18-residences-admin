import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class PaymentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentEvent {}

/// Adds a payment method, then uploads its QR image [png] (already converted in the browser), if any.
class CreatePaymentMethod extends PaymentEvent {
  final PaymentMethodRequest request;
  final Uint8List? png;

  CreatePaymentMethod(this.request, this.png);

  @override
  List<Object?> get props => [request, png];
}

class UpdatePaymentMethod extends PaymentEvent {
  final int id;
  final PaymentMethodRequest request;

  UpdatePaymentMethod(this.id, this.request);

  @override
  List<Object?> get props => [id, request];
}

class DeletePaymentMethod extends PaymentEvent {
  final PaymentMethod method;
  final Completer<void> onComplete;

  DeletePaymentMethod(this.method, {required this.onComplete});

  @override
  List<Object?> get props => [method, onComplete];
}

/// Replaces (or adds) [method]'s QR image with [png] (already converted in the browser).
class UploadPaymentImage extends PaymentEvent {
  final PaymentMethod method;
  final Uint8List png;

  UploadPaymentImage(this.method, this.png);

  @override
  List<Object?> get props => [method, png];
}

class RemovePaymentImage extends PaymentEvent {
  final PaymentMethod method;
  final Completer<void> onComplete;

  RemovePaymentImage(this.method, {required this.onComplete});

  @override
  List<Object?> get props => [method, onComplete];
}
