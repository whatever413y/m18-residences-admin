import 'package:equatable/equatable.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

abstract class RoomState extends Equatable {
  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {}

class RoomLoading extends RoomState {}

class AddSuccess extends RoomState {}

class UpdateSuccess extends RoomState {}

class DeleteSuccess extends RoomState {}

class RoomLoaded extends RoomState {
  final List<Room> rooms;

  RoomLoaded(this.rooms);

  @override
  List<Object?> get props => [rooms];
}

class RoomError extends RoomState {
  final String message;

  RoomError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating, updating or deleting a room failed; the page keeps showing the rooms and reports [message].
class RoomActionFailed extends RoomState {
  static int _count = 0;

  final String message;

  /// Makes every failure a new state, so the same failure twice in a row is reported twice.
  final int _id = _count++;

  RoomActionFailed(this.message);

  @override
  List<Object?> get props => [message, _id];
}
