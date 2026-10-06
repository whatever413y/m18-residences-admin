import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/billing/billings_page.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_state.dart';
import 'package:m18_residences_admin/features/dashboard/dashboard_page.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_bloc.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_event.dart';
import 'package:m18_residences_admin/features/payments/payments_page.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_bloc.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_event.dart';
import 'package:m18_residences_admin/features/reading/readings_page.dart';
import 'package:m18_residences_admin/features/room/bloc/room_bloc.dart';
import 'package:m18_residences_admin/features/room/bloc/room_event.dart';
import 'package:m18_residences_admin/features/room/rooms_page.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_bloc.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_event.dart';
import 'package:m18_residences_admin/features/tenants/tenants_page.dart';
import 'package:m18_residences_admin/features/verify/verify_page.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

enum AdminTab { dashboard, verify, billing, readings, tenants, rooms, payments }

/// Which bills the Billing page should show when opened from search or the dashboard.
class BillFilter {
  final int? tenantId;
  final int? roomId;

  const BillFilter({this.tenantId, this.roomId});
}

/// The admin app after login: Dashboard, Verify, Billing, Electric Readings, Tenants, Rooms and Payment QR Codes,
/// as an extended rail on desktops, a rail on tablets and a bottom bar (with "More") on phones. Opening a page
/// reloads its data (pages stay built, so filters and scroll positions are kept). Bill results (created, updated, deleted, failed) are reported here, so
/// they show once whichever page started them.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  /// The shell around [context], for switching pages from a page or from search.
  static AdminShellState of(BuildContext context) => context.findAncestorStateOfType<AdminShellState>()!;

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  AdminTab _tab = AdminTab.dashboard;

  /// Set by search and the dashboard; the Billing page applies it.
  final billFilter = ValueNotifier<BillFilter?>(null);

  /// The last loaded billing data (bills, rooms, tenants, readings), kept while actions run.
  BillingLoaded? billing;

  @override
  void initState() {
    super.initState();
    // The dashboard (and search) need the bills, rooms and tenants; other pages load when opened.
    _load(AdminTab.dashboard);
  }

  @override
  void dispose() {
    billFilter.dispose();
    super.dispose();
  }

  /// Shows [tab] with fresh data, as opening a page did before the shell (a room added in Rooms then shows up in
  /// the tenant form, a new tenant in the reading form, and so on).
  void select(AdminTab tab) {
    _load(tab);
    setState(() => _tab = tab);
  }

  void _load(AdminTab tab) => switch (tab) {
    AdminTab.dashboard || AdminTab.verify || AdminTab.billing => context.read<BillingBloc>().add(LoadBills()),
    AdminTab.readings => context.read<ReadingBloc>().add(LoadReadings()),
    AdminTab.tenants => context.read<TenantBloc>().add(LoadTenants()),
    AdminTab.rooms => context.read<RoomBloc>().add(LoadRooms()),
    AdminTab.payments => context.read<PaymentBloc>().add(LoadPayments()),
  };

  /// Opens Billing showing all bills of a tenant or of a room.
  void showBills({int? tenantId, int? roomId}) {
    billFilter.value = BillFilter(tenantId: tenantId, roomId: roomId);
    select(AdminTab.billing);
  }

  static bool _isData(BillingState state) => state is BillingLoading || state is BillingLoaded || state is BillingError;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
      builder: (context, authState) {
        if (authState is Unauthenticated) return Scaffold(body: ErrorView(message: authState.message));
        return BlocListener<BillingBloc, BillingState>(
          listener: _reportBillResult,
          child: BlocBuilder<BillingBloc, BillingState>(
            buildWhen: (_, state) => _isData(state),
            builder: (context, state) {
              if (state is BillingLoaded) billing = state;
              final toVerify = billing?.bills.where((b) => b.status == BillStatus.forVerification).length ?? 0;
              return AdaptiveScaffold(
                selectedIndex: _tab.index,
                onDestinationSelected: (i) => select(AdminTab.values[i]),
                railHeader: (context, extended) => BrandMark(label: extended ? 'M18 Admin' : null),
                railFooter: (context, extended) => extended
                    ? TextButton.icon(
                        style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                        onPressed: () => LogoutScope.logout(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      )
                    : IconButton(tooltip: 'Logout', onPressed: () => LogoutScope.logout(context), icon: const Icon(Icons.logout)),
                moreSheetFooter: (sheetContext) => [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      LogoutScope.logout(context);
                    },
                  ),
                ],
                destinations: [
                  const AdaptiveDestination(
                    label: 'Dashboard',
                    compactLabel: 'Home',
                    icon: Icons.space_dashboard_outlined,
                    selectedIcon: Icons.space_dashboard,
                  ),
                  AdaptiveDestination(label: 'Verify', icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, badgeCount: toVerify),
                  const AdaptiveDestination(label: 'Billing', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
                  const AdaptiveDestination(
                    label: 'Electric Readings',
                    compactLabel: 'Readings',
                    icon: Icons.bolt_outlined,
                    selectedIcon: Icons.bolt,
                  ),
                  const AdaptiveDestination(label: 'Tenants', icon: Icons.people_outline, selectedIcon: Icons.people),
                  const AdaptiveDestination(label: 'Rooms', icon: Icons.meeting_room_outlined, selectedIcon: Icons.meeting_room),
                  const AdaptiveDestination(label: 'Payment QR Codes', icon: Icons.qr_code_2_outlined, selectedIcon: Icons.qr_code_2),
                ],
                body: IndexedStack(
                  index: _tab.index,
                  // Each page selects its own text only (a hidden page's text is not picked up by a drag).
                  children: [
                    for (final page in const [
                      DashboardPage(),
                      VerifyPage(),
                      BillingsPage(),
                      ReadingsPage(),
                      TenantsPage(),
                      RoomsPage(),
                      PaymentsPage(),
                    ])
                      SelectablePage(child: page),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _reportBillResult(BuildContext context, BillingState state) {
    if (state is BillingActionFailed) {
      AppToast.show(context, state.message, type: ToastType.error);
    } else if (state is BillingError) {
      AppToast.hide();
      // A failed load may mean the session expired; the auth check then shows the login error.
      context.read<AuthBloc>().add(CheckAuthStatus());
    } else if (state is AddSuccess) {
      AppToast.show(context, 'Bill created', type: ToastType.success);
    } else if (state is UpdateSuccess) {
      AppToast.show(context, 'Bill updated', type: ToastType.success);
    } else if (state is DeleteSuccess) {
      AppToast.show(context, 'Bill deleted', type: ToastType.success);
    }
  }
}
