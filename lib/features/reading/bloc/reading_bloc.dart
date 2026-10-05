import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'reading_event.dart';
import 'reading_state.dart';

class ReadingBloc extends Bloc<ReadingEvent, ReadingState> {
  final ReadingApi readingApi;
  final RoomApi roomApi;
  final TenantApi tenantApi;

  ReadingBloc({required this.readingApi, required this.roomApi, required this.tenantApi}) : super(ReadingInitial()) {
    on<LoadReadings>(_onLoadReadings);
    on<AddReading>(_onAddReading);
    on<UpdateReading>(_onUpdateReading);
    on<DeleteReading>(_onDeleteReading);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadReadings(LoadReadings event, Emitter<ReadingState> emit) async {
    emit(ReadingLoading());
    try {
      // Independent requests, sent together; the first failure is reported.
      final data = await Future.wait<Object>([readingApi.list(), roomApi.list(), tenantApi.list()]);
      emit(ReadingLoaded(data[0] as List<Reading>, data[1] as List<Room>, data[2] as List<Tenant>));
    } catch (e) {
      emit(ReadingError('Failed to load readings: ${_reason(e)}'));
    }
  }

  Future<void> _onAddReading(AddReading event, Emitter<ReadingState> emit) async {
    try {
      await readingApi.create(event.request);
      add(LoadReadings());
      emit(AddSuccess());
    } catch (e) {
      emit(ReadingActionFailed('Failed to add reading: ${_reason(e)}'));
    }
  }

  Future<void> _onUpdateReading(UpdateReading event, Emitter<ReadingState> emit) async {
    try {
      await readingApi.update(event.id, event.request);
      add(LoadReadings());
      emit(UpdateSuccess());
    } catch (e) {
      emit(ReadingActionFailed('Failed to update reading: ${_reason(e)}'));
    }
  }

  Future<void> _onDeleteReading(DeleteReading event, Emitter<ReadingState> emit) async {
    try {
      await readingApi.delete(event.id);
      event.onComplete.complete();
      add(LoadReadings());
      emit(DeleteSuccess());
    } catch (e) {
      event.onComplete.completeError(e);
      emit(ReadingActionFailed('Failed to delete reading: ${_reason(e)}'));
    }
  }
}
