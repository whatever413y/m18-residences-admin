import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_bloc.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_event.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_state.dart';
import 'package:m18_residences_admin/features/tenants/widgets/tenant_card.dart';
import 'package:m18_residences_admin/features/tenants/widgets/tenant_form_dialog.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/custom_add_button.dart';
import 'package:m18_residences_admin/utils/custom_snackbar.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  late AuthBloc authBloc;
  late TenantBloc tenantBloc;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc.add(CheckAuthStatus());
    tenantBloc = context.read<TenantBloc>();
    tenantBloc.add(LoadTenants());
  }

  Future<void> _showTenantDialog({Tenant? tenant, required List<Room> rooms, bool isEditing = false}) async {
    final result = await showSelectableDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => TenantFormDialog(tenant: tenant, rooms: rooms, isEditing: isEditing),
    );

    if (!mounted) return;
    if (result == null) return;

    final request = TenantRequest(
      name: result['name'] as String,
      roomId: result['roomId'] as int,
      joinDate: result['joinDate'] as DateTime,
      // Only updates send the active flag; the server makes new tenants active.
      isActive: tenant != null ? result['isActive'] as bool : null,
    );

    if (tenant != null) {
      tenantBloc.add(UpdateTenantEvent(tenant.id, request));
    } else {
      tenantBloc.add(AddTenant(request));
    }
  }

  Future<void> _confirmDelete(Tenant tenant) async {
    final messenger = ScaffoldMessenger.of(context);
    await showConfirmationAction(
      context: context,
      messenger: messenger,
      confirmTitle: 'Confirm Deletion',
      confirmContent: 'Are you sure you want to delete this tenant?',
      onConfirmed: () async {
        await _deleteTenant(tenant.id);
      },
    );
  }

  Future<void> _deleteTenant(int id) async {
    final completer = Completer<void>();
    tenantBloc.add(DeleteTenant(id, onComplete: completer));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is Unauthenticated) {
          return ErrorView(message: authState.message);
        }

        return Theme(
          data: theme,
          child: Scaffold(
            appBar: CustomAppBar(
              title: 'Tenants',
              showRefresh: true,
              onRefresh: () {
                tenantBloc.add(LoadTenants());
              },
              actions: [
                buildActiveToggleFilter(
                  showActiveOnly: _showActiveOnly,
                  onChanged: (val) {
                    setState(() => _showActiveOnly = val);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: BlocListener<TenantBloc, TenantState>(
              listener: (context, state) {
                if (state is TenantActionFailed) {
                  CustomSnackbar.show(context, state.message, type: SnackBarType.error, duration: const Duration(seconds: 6));
                } else if (state is TenantError) {
                  // A failed load may mean the session expired; the auth check then shows the login error.
                  authBloc.add(CheckAuthStatus());
                } else if (state is AddSuccess) {
                  CustomSnackbar.show(context, 'Tenant created', type: SnackBarType.success);
                } else if (state is UpdateSuccess) {
                  CustomSnackbar.show(context, 'Tenant updated', type: SnackBarType.success);
                } else if (state is DeleteSuccess) {
                  CustomSnackbar.show(context, 'Tenant deleted', type: SnackBarType.success);
                }
              },
              child: BlocBuilder<TenantBloc, TenantState>(
                // Only data loads change what the page shows; action results are reported by the listener.
                buildWhen: (_, state) => state is TenantInitial || state is TenantLoading || state is TenantLoaded || state is TenantError,
                builder: (context, state) {
                  if (state is TenantLoading || state is TenantInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is TenantError) {
                    return ErrorView(message: state.message, onRetry: () => tenantBloc.add(LoadTenants()));
                  }

                  if (state is TenantLoaded) {
                    return _buildTenantList(context, state.tenants, state.rooms);
                  }

                  return const SizedBox();
                },
              ),
            ),
            floatingActionButton: CustomAddButton(
              onPressed: () {
                final state = tenantBloc.state;
                if (state is TenantLoaded) {
                  _showTenantDialog(rooms: state.rooms);
                }
              },
              label: 'New Tenant',
            ),
          ),
        );
      },
    );
  }

  Widget _buildTenantList(BuildContext context, List<Tenant> tenants, List<Room> rooms) {
    if (tenants.isEmpty) {
      return const Center(child: Text('No tenants available.'));
    }

    final filteredTenants = _showActiveOnly ? tenants.where((tenant) => tenant.isActive).toList() : tenants;

    return ResponsiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: () async {
            tenantBloc.add(LoadTenants());
            await tenantBloc.stream.firstWhere((state) => state is! TenantLoading);
          },
          child: !context.windowSize.isCompact
              ? GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // A fixed height that fits the card (two icon buttons), whatever the column width.
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 160,
                  ),
                  itemCount: filteredTenants.length,
                  itemBuilder: (context, index) {
                    final tenant = filteredTenants[index];
                    final room = rooms.firstWhere((r) => r.id == tenant.roomId, orElse: () => Room(id: -1, name: 'Unknown', rent: 0));

                    return TenantCard(
                      tenant: tenant,
                      room: room,
                      onEdit: () => _showTenantDialog(tenant: tenant, rooms: rooms, isEditing: true),
                      onDelete: () => _confirmDelete(tenant),
                    );
                  },
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredTenants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final tenant = filteredTenants[index];
                    final room = rooms.firstWhere((r) => r.id == tenant.roomId, orElse: () => Room(id: -1, name: 'Unknown', rent: 0));

                    return TenantCard(
                      tenant: tenant,
                      room: room,
                      onEdit: () => _showTenantDialog(tenant: tenant, rooms: rooms, isEditing: true),
                      onDelete: () => _confirmDelete(tenant),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
