import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginWithAccountId extends AuthEvent {
  final String username;
  final String password;

  /// The login page's Turnstile token (single use).
  final String? turnstileToken;

  LoginWithAccountId({required this.username, required this.password, this.turnstileToken});
}

class LogoutRequested extends AuthEvent {}
