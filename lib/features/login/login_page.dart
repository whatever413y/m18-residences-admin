import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/shell/admin_shell.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _turnstile = TurnstileController();

  /// Login was asked for before the verification finished: log in as soon as it does.
  bool _submitWhenVerified = false;

  String? _usernameError;
  String? _passwordError;
  bool _obscurePassword = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  void initState() {
    super.initState();
    _turnstile.addListener(_onVerified);
  }

  @override
  void dispose() {
    _turnstile
      ..removeListener(_onVerified)
      ..dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onVerified() {
    if (_submitWhenVerified && _turnstile.token != null) {
      setState(() => _submitWhenVerified = false);
      _submitLogin();
    }
  }

  void _submitLogin() {
    setState(() {
      _usernameError = null;
      _passwordError = null;
    });

    if (_formKey.currentState?.validate() ?? false) {
      final token = _turnstile.token;
      if (token == null) {
        setState(() => _submitWhenVerified = true);
        return;
      }
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      context.read<AuthBloc>().add(LoginWithAccountId(username: username, password: password, turnstileToken: token));
      // Tokens are single use: the next attempt needs a new one.
      _turnstile.reset();
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() {
              _usernameError = state.message;
              _passwordError = state.message;
            });
            _formKey.currentState?.validate();
          } else if (state is Authenticated) {
            _usernameController.clear();
            _passwordController.clear();
            if (!Navigator.of(context).canPop()) {
              _navigateToPage(const AdminShell());
            }
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _buildContent(context)),
                  ),
                ),
              ),
              if (state is AuthLoading) const LoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandMark(size: 56)),
        const SizedBox(height: 20),
        Text('M18 Residences', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Rooms, tenants, readings and bills in one place.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Admin Login', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Sign in with the owner account.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 20),
                  _buildUsernameField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  TurnstileField(controller: _turnstile, action: 'admin-login'),
                  const SizedBox(height: 16),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return CustomTextFormField(
      controller: _usernameController,
      labelText: 'Username',
      semanticsId: 'admin-username',
      autofocus: true,
      // Enter moves on to the password field.
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.person_outline),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your username';
        }
        return _usernameError;
      },
    );
  }

  Widget _buildPasswordField() {
    return CustomTextFormField(
      controller: _passwordController,
      labelText: 'Password',
      semanticsId: 'admin-password',
      prefixIcon: const Icon(Icons.lock_outline),
      obscureText: _obscurePassword,
      onFieldSubmitted: (_) => _submitLogin(),
      suffixIcon: IconButton(
        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: _togglePasswordVisibility,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your password';
        }
        return _passwordError;
      },
    );
  }

  Widget _buildLoginButton() {
    return Semantics(
      container: true,
      identifier: 'admin-login-submit',
      // Pressed before the verification above has finished, it logs in once it has.
      child: FilledButton(onPressed: _submitLogin, child: Text(_submitWhenVerified ? 'Verifying…' : 'Login')),
    );
  }
}
