import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/bloc_providers.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

import 'features/login/login_page.dart';

void main() {
  // Fails right away with a clear StateError when the app was built without API_URL (see .env.example).
  ApiConfig.baseUrl;
  runApp(MyApp());
  // Browser e2e builds (--dart-define=E2E=true) need the semantics tree so tests can find widgets by identifier.
  if (const bool.fromEnvironment('E2E')) SemanticsBinding.instance.ensureSemantics();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: blocProviders,
      child: LogoutScope(
        onLogout: (context) {
          context.read<AuthBloc>().add(LogoutRequested());
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()), (route) => false);
        },
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'M18 Residences Admin',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          home: LoginPage(),
        ),
      ),
    );
  }
}
