import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_bloc.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_bloc.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_event.dart';
import 'package:m18_residences_admin/features/room/bloc/room_bloc.dart';
import 'package:m18_residences_admin/features/room/bloc/room_event.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_bloc.dart';
import 'package:m18_residences_admin/features/tenants/bloc/tenant_event.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// One API client (and session store) shared by every endpoint wrapper.
final ApiClient _apiClient = ApiClient(tokens: const TokenStore('admin_id'));
final AuthApi _authApi = AuthApi(_apiClient);
final BillApi _billApi = BillApi(_apiClient);
final PaymentApi _paymentApi = PaymentApi(_apiClient);
final ReadingApi _readingApi = ReadingApi(_apiClient);
final RoomApi _roomApi = RoomApi(_apiClient);
final TenantApi _tenantApi = TenantApi(_apiClient);

final List<BlocProvider> blocProviders = [
  BlocProvider<AuthBloc>(create: (_) => AuthBloc(authApi: _authApi)..add(CheckAuthStatus())),
  BlocProvider<RoomBloc>(create: (_) => RoomBloc(_roomApi)..add(LoadRooms())),
  BlocProvider<TenantBloc>(
    create: (_) => TenantBloc(tenantApi: _tenantApi, roomApi: _roomApi)..add(LoadTenants()),
  ),
  BlocProvider<ReadingBloc>(
    create: (_) => ReadingBloc(readingApi: _readingApi, roomApi: _roomApi, tenantApi: _tenantApi)..add(LoadReadings()),
  ),
  BlocProvider<BillingBloc>(
    create: (_) => BillingBloc(readingApi: _readingApi, roomApi: _roomApi, tenantApi: _tenantApi, billApi: _billApi)..add(LoadBills()),
  ),
  // Loads when the Payments page opens.
  BlocProvider<PaymentBloc>(create: (_) => PaymentBloc(_paymentApi)),
];
