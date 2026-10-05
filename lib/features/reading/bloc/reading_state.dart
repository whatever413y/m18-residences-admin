import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class ReadingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ReadingInitial extends ReadingState {}

class ReadingLoading extends ReadingState {}

class AddSuccess extends ReadingState {}

class UpdateSuccess extends ReadingState {}

class DeleteSuccess extends ReadingState {}

class ReadingLoaded extends ReadingState {
  final List<Reading> readings;
  final List<Room> rooms;
  final List<Tenant> tenants;

  ReadingLoaded(this.readings, this.rooms, this.tenants);

  @override
  List<Object?> get props => [readings, rooms, tenants];
}

/// Loading the readings failed; the page shows the error instead of the readings.
class ReadingError extends ReadingState {
  final String message;

  ReadingError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating, updating or deleting a reading failed; the page keeps showing the readings and reports [message].
class ReadingActionFailed extends ReadingState {
  static int _count = 0;

  final String message;

  /// Makes every failure a new state, so the same failure twice in a row is reported twice.
  final int _id = _count++;

  ReadingActionFailed(this.message);

  @override
  List<Object?> get props => [message, _id];
}
