import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/home/home_page.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _usernameError;
  String? _passwordError;
  bool _obscurePassword = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _submitLogin() {
    setState(() {
      _usernameError = null;
      _passwordError = null;
    });

    if (_formKey.currentState?.validate() ?? false) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      context.read<AuthBloc>().add(LoginWithAccountId(username: username, password: password));
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;
    final primaryColor = theme.primaryColor;

    return Theme(
      data: theme,
      child: Scaffold(
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
                _navigateToPage(HomePage());
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return _buildLoading(
              isLoading,
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final cardWidth = maxWidth < 600 ? maxWidth * 0.9 : 600.0;

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor.withAlpha(230), primaryColor.withAlpha(150)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardWidth),
                            child: Padding(padding: const EdgeInsets.all(16.0), child: _buildCard(primaryColor)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(bool isLoading, Widget child) {
    return Stack(children: [child, if (isLoading) LoadingOverlay()]);
  }

  Widget _buildCard(Color primaryColor) {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin Login',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildUsernameField(primaryColor),
              const SizedBox(height: 15),
              _buildPasswordField(primaryColor),
              const SizedBox(height: 20),
              _buildLoginButton(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField(Color primaryColor) {
    return CustomTextFormField(
      controller: _usernameController,
      labelText: 'Username',
      semanticsId: 'admin-username',
      autofocus: true,
      // Enter moves on to the password field.
      textInputAction: TextInputAction.next,
      prefixIcon: Icon(Icons.person, color: primaryColor),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your username';
        }
        return _usernameError;
      },
    );
  }

  Widget _buildPasswordField(Color primaryColor) {
    return CustomTextFormField(
      controller: _passwordController,
      labelText: 'Password',
      semanticsId: 'admin-password',
      prefixIcon: Icon(Icons.lock, color: primaryColor),
      obscureText: _obscurePassword,
      onFieldSubmitted: (_) => _submitLogin(),
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: primaryColor),
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

  Widget _buildLoginButton(Color primaryColor) {
    return Semantics(
      container: true,
      identifier: 'admin-login-submit',
      child: ElevatedButton(
        onPressed: _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Login', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
