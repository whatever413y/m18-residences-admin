import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_bloc.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_event.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_state.dart';
import 'package:m18_residences_admin/features/payments/widgets/payment_card.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_admin/utils/custom_snackbar.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The payment methods' QR codes tenants pay with: view, save and replace them.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final PaymentBloc paymentBloc = context.read<PaymentBloc>();

  void _replace(String name, Uint8List png) {
    // Replaced by the bloc's result (see the listener).
    CustomSnackbar.show(context, 'Uploading the ${paymentMethodLabels[name] ?? name} QR code...', type: SnackBarType.loading);
    paymentBloc.add(ReplacePayment(name, png));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(title: 'Payment QR Codes', onRefresh: () => paymentBloc.add(LoadPayments())),
      body: BlocListener<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentActionFailed) {
            CustomSnackbar.show(context, state.message, type: SnackBarType.error, duration: const Duration(seconds: 6));
          } else if (state is PaymentError) {
            CustomSnackbar.hide(context);
            // A failed load may mean the session expired; the auth check then shows the login error.
            context.read<AuthBloc>().add(CheckAuthStatus());
          } else if (state is PaymentReplaced) {
            CustomSnackbar.show(context, '${paymentMethodLabels[state.name] ?? state.name} QR code replaced', type: SnackBarType.success);
          }
        },
        child: BlocBuilder<PaymentBloc, PaymentState>(
          // Only data loads change what the page shows; action results are reported by the listener.
          buildWhen: (_, state) => state is PaymentInitial || state is PaymentLoading || state is PaymentLoaded || state is PaymentError,
          builder: (context, state) {
            if (state is PaymentError) {
              return ErrorView(message: state.message, onRetry: () => paymentBloc.add(LoadPayments()));
            }
            if (state is! PaymentLoaded) return const Center(child: CircularProgressIndicator());
            return _buildCards(context, state.images);
          },
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context, List<PaymentImage> images) {
    final authApi = context.read<AuthBloc>().authApi;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.windowSize.isCompact ? 16 : 24, vertical: 20),
      child: ResponsiveCenter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // One column on phones, three side by side on wider screens.
            final columns = constraints.maxWidth < WindowSize.mediumMin ? 1 : 3;
            final cardWidth = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final image in images)
                  SizedBox(
                    width: cardWidth,
                    child: PaymentCard(
                      image: image,
                      fetchFile: () => authApi.signedPaymentUrl(image.name),
                      onReplace: (png) => _replace(image.name, png),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
