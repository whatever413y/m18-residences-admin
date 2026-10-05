import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/room/bloc/room_event.dart';
import 'package:m18_residences_admin/features/room/bloc/room_state.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final RoomApi roomApi;

  RoomBloc(this.roomApi) : super(RoomInitial()) {
    on<LoadRooms>(_onLoadRooms);
    on<AddRoom>(_onAddRoom);
    on<UpdateRoom>(_onUpdateRoom);
    on<DeleteRoom>(_onDeleteRoom);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadRooms(LoadRooms event, Emitter<RoomState> emit) async {
    emit(RoomLoading());
    try {
      final rooms = await roomApi.list();
      emit(RoomLoaded(rooms));
    } catch (e) {
      emit(RoomError('Failed to load rooms: ${_reason(e)}'));
    }
  }

  Future<void> _onAddRoom(AddRoom event, Emitter<RoomState> emit) async {
    try {
      await roomApi.create(event.request);
      add(LoadRooms());
      emit(AddSuccess());
    } catch (e) {
      emit(RoomActionFailed('Failed to create room: ${_reason(e)}'));
    }
  }

  Future<void> _onUpdateRoom(UpdateRoom event, Emitter<RoomState> emit) async {
    try {
      await roomApi.update(event.id, event.request);
      add(LoadRooms());
      emit(UpdateSuccess());
    } catch (e) {
      emit(RoomActionFailed('Failed to update room: ${_reason(e)}'));
    }
  }

  Future<void> _onDeleteRoom(DeleteRoom event, Emitter<RoomState> emit) async {
    try {
      await roomApi.delete(event.id);
      event.onComplete.complete();
      add(LoadRooms());
      emit(DeleteSuccess());
    } catch (e) {
      event.onComplete.completeError(e);
      emit(RoomActionFailed('Failed to delete room: ${_reason(e)}'));
    }
  }
}
