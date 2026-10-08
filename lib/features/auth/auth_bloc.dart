import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/models/admin.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthApi authApi;

  Admin? _cachedAdmin;

  AuthBloc({required this.authApi}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginWithAccountId>(_onLoginWithAccountId);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    try {
      final isAuth = await authApi.validateToken();
      if (!isAuth) {
        return emit(Unauthenticated('Session has expired. Please try again'));
      }

      final token = await authApi.tokens.token();
      final adminUsername = await authApi.tokens.subject();

      if (token == null || adminUsername == null) {
        return emit(Unauthenticated('Token or user missing'));
      }

      _cachedAdmin = Admin(username: adminUsername);
      emit(Authenticated(token: token, admin: _cachedAdmin!));
    } catch (e) {
      emit(Unauthenticated('Auth error: $e'));
    }
  }

  Future<void> _onLoginWithAccountId(LoginWithAccountId event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final session = await authApi.adminLogin(event.username, event.password, turnstileToken: event.turnstileToken);
      final admin = Admin(username: session.username);
      _cachedAdmin = admin;
      emit(Authenticated(token: session.token, admin: admin));
    } on InvalidCredentialsException {
      emit(AuthError('Invalid credentials'));
    } on TooManyAttemptsException {
      emit(AuthError('Too many attempts. Please wait a minute and try again.'));
    } on VerificationFailedException catch (e) {
      emit(AuthError(e.unavailable ? "Couldn't verify right now. Please try again." : 'Verification failed. Please try again.'));
    } on TimeoutException {
      emit(AuthError('Connection timed out. Please try again.'));
    } on SocketException {
      emit(AuthError('Network error. Please check your connection.'));
    } catch (e) {
      emit(AuthError('Unexpected error: ${e.toString()}'));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await authApi.logout();
    _cachedAdmin = null;
    emit(Unauthenticated('You have been logged out.'));
  }

  Admin? get cachedAdmin => _cachedAdmin;
}
