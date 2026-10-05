import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class TenantState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TenantInitial extends TenantState {}

class TenantLoading extends TenantState {}

class AddSuccess extends TenantState {}

class UpdateSuccess extends TenantState {}

class DeleteSuccess extends TenantState {}

class TenantLoaded extends TenantState {
  final List<Tenant> tenants;
  final List<Room> rooms;

  TenantLoaded(this.tenants, this.rooms);

  @override
  List<Object?> get props => [tenants, rooms];
}

class TenantError extends TenantState {
  final String message;

  TenantError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating, updating or deleting a tenant failed; the page keeps showing the tenants and reports [message].
class TenantActionFailed extends TenantState {
  static int _count = 0;

  final String message;

  /// Makes every failure a new state, so the same failure twice in a row is reported twice.
  final int _id = _count++;

  TenantActionFailed(this.message);

  @override
  List<Object?> get props => [message, _id];
}
