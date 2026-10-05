import 'dart:typed_data';

import 'package:equatable/equatable.dart';

abstract class PaymentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentEvent {}

/// Replaces the QR image of the payment method [name] with [png] (already converted in the browser).
class ReplacePayment extends PaymentEvent {
  final String name;
  final Uint8List png;

  ReplacePayment(this.name, this.png);

  @override
  List<Object?> get props => [name, png];
}
