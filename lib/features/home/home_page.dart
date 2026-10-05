import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/billing/billings_page.dart';
import 'package:m18_residences_admin/features/home/widgets/square_button.dart';
import 'package:m18_residences_admin/features/payments/payments_page.dart';
import 'package:m18_residences_admin/features/reading/readings_page.dart';
import 'package:m18_residences_admin/features/room/rooms_page.dart';
import 'package:m18_residences_admin/features/tenants/tenants_page.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late AuthBloc authBloc;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc.add(CheckAuthStatus());
  }

  void _navigateToPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((updated) {
      if (updated == true) {
        authBloc.add(CheckAuthStatus());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;
    final primaryColor = theme.primaryColor;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: CustomAppBar(title: 'Welcome Admin!', logoutOnBack: true),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Unauthenticated) {
              return ErrorView(message: state.message);
            }

            return Container(
              // The gradient fills the screen, however few buttons there are.
              constraints: const BoxConstraints.expand(),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor.withValues(alpha: 0.9), primaryColor.withValues(alpha: 0.6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: ResponsiveCenter(
                  maxWidth: 960,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // One column on phones, two on tablets, three on desktops.
                      final columns = switch (WindowSize.fromWidth(constraints.maxWidth)) {
                        WindowSize.compact => 1,
                        WindowSize.medium => 2,
                        WindowSize.expanded => 3,
                      };
                      const gap = 20.0;
                      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                      final buttons = [
                        SquareButton(text: "Rooms", icon: Icons.meeting_room, onTap: () => _navigateToPage(RoomsPage()), color: primaryColor),
                        SquareButton(text: "Tenants", icon: Icons.people, onTap: () => _navigateToPage(TenantsPage()), color: primaryColor),
                        SquareButton(
                          text: "Electric Readings",
                          icon: Icons.flash_on,
                          onTap: () => _navigateToPage(ReadingsPage()),
                          color: primaryColor,
                        ),
                        SquareButton(text: "Billing", icon: Icons.receipt_long, onTap: () => _navigateToPage(BillingsPage()), color: primaryColor),
                        SquareButton(
                          text: "Payment QR Codes",
                          icon: Icons.qr_code_2,
                          onTap: () => _navigateToPage(const PaymentsPage()),
                          color: primaryColor,
                        ),
                      ];
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [for (final button in buttons) SizedBox(width: width, child: button)],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
