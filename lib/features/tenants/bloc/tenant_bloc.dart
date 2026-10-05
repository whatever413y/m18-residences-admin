import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_event.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_state.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class TenantBloc extends Bloc<TenantEvent, TenantState> {
  final TenantApi tenantApi;
  final RoomApi roomApi;

  TenantBloc({required this.tenantApi, required this.roomApi}) : super(TenantInitial()) {
    on<LoadTenants>(_onLoadTenants);
    on<AddTenant>(_onAddTenant);
    on<UpdateTenantEvent>(_onUpdateTenant);
    on<DeleteTenant>(_onDeleteTenant);
  }

  static String _reason(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _onLoadTenants(LoadTenants event, Emitter<TenantState> emit) async {
    emit(TenantLoading());
    try {
      // Independent requests, sent together; the first failure is reported.
      final data = await Future.wait<Object>([tenantApi.list(), roomApi.list()]);
      emit(TenantLoaded(data[0] as List<Tenant>, data[1] as List<Room>));
    } catch (e) {
      emit(TenantError('Failed to load tenants: ${_reason(e)}'));
    }
  }

  Future<void> _onAddTenant(AddTenant event, Emitter<TenantState> emit) async {
    try {
      await tenantApi.create(event.request);
      add(LoadTenants());
      emit(AddSuccess());
    } catch (e) {
      emit(TenantActionFailed('Failed to add tenant: ${_reason(e)}'));
    }
  }

  Future<void> _onUpdateTenant(UpdateTenantEvent event, Emitter<TenantState> emit) async {
    try {
      await tenantApi.update(event.id, event.request);
      add(LoadTenants());
      emit(UpdateSuccess());
    } catch (e) {
      emit(TenantActionFailed('Failed to update tenant: ${_reason(e)}'));
    }
  }

  Future<void> _onDeleteTenant(DeleteTenant event, Emitter<TenantState> emit) async {
    try {
      await tenantApi.delete(event.id);
      event.onComplete.complete();
      add(LoadTenants());
      emit(DeleteSuccess());
    } catch (e) {
      event.onComplete.completeError(e);
      emit(TenantActionFailed('Failed to delete tenant: ${_reason(e)}'));
    }
  }
}
