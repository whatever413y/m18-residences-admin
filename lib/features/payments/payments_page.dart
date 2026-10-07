import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_bloc.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_event.dart';
import 'package:m18_residences_admin/features/payments/bloc/payment_state.dart';
import 'package:m18_residences_admin/features/payments/widgets/payment_card.dart';
import 'package:m18_residences_admin/features/payments/widgets/payment_method_form_dialog.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/custom_add_button.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The payment methods tenants pay with: add, edit, reorder and delete them, and view, save, upload and remove
/// their QR codes.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final PaymentBloc paymentBloc = context.read<PaymentBloc>();

  Future<void> _showForm({PaymentMethod? method}) async {
    final result = await showAppModal<PaymentMethodFormResult>(context, builder: (_) => PaymentMethodFormDialog(method: method));
    if (result == null || !mounted) return;
    // Replaced by the bloc's result (see the listener).
    AppToast.show(context, method == null ? 'Adding ${result.request.name}...' : 'Saving ${result.request.name}...', type: ToastType.loading);
    paymentBloc.add(method == null ? CreatePaymentMethod(result.request, result.png) : UpdatePaymentMethod(method.id, result.request));
  }

  void _upload(PaymentMethod method, Uint8List png) {
    AppToast.show(context, 'Uploading the ${method.name} QR code...', type: ToastType.loading);
    paymentBloc.add(UploadPaymentImage(method, png));
  }

  Future<void> _confirmRemoveImage(PaymentMethod method) => showConfirmationAction(
    context: context,
    title: 'Remove the ${method.name} QR code?',
    message: 'Tenants still see the account details. The image is kept in the archive.',
    confirmLabel: 'Remove QR code',
    onConfirmed: () {
      final done = Completer<void>();
      paymentBloc.add(RemovePaymentImage(method, onComplete: done));
      return done.future;
    },
  );

  Future<void> _confirmDelete(PaymentMethod method) => showConfirmationAction(
    context: context,
    title: 'Delete ${method.name}?',
    message: 'Tenants no longer see it under Pay. Its QR code is kept in the archive.',
    confirmLabel: 'Delete payment method',
    onConfirmed: () {
      final done = Completer<void>();
      paymentBloc.add(DeletePaymentMethod(method, onComplete: done));
      return done.future;
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(title: 'Payment QR Codes', onRefresh: () => paymentBloc.add(LoadPayments())),
      floatingActionButton: CustomAddButton(onPressed: () => _showForm(), label: 'New Payment Method'),
      body: BlocListener<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentActionFailed) {
            AppToast.show(context, state.message, type: ToastType.error);
          } else if (state is PaymentError) {
            AppToast.hide();
            // A failed load may mean the session expired; the auth check then shows the login error.
            context.read<AuthBloc>().add(CheckAuthStatus());
          } else if (state is PaymentActionSucceeded) {
            AppToast.show(context, state.message, type: ToastType.success);
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
            if (state.methods.isEmpty) {
              return const EmptyState(
                icon: Icons.qr_code_2,
                title: 'No payment methods yet',
                message: 'Add the banks and e-wallets tenants pay to with New Payment Method.',
              );
            }
            return _buildCards(context, state.methods);
          },
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context, List<PaymentMethod> methods) {
    final authApi = context.read<AuthBloc>().authApi;
    return SingleChildScrollView(
      // Room at the bottom for the floating button.
      padding: EdgeInsets.fromLTRB(context.windowSize.isCompact ? 16 : 24, 20, context.windowSize.isCompact ? 16 : 24, 96),
      child: ResponsiveCenter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // About 320-460 px per card: one column on phones, up to four on large screens.
            final columns = (constraints.maxWidth / 340).floor().clamp(1, 4);
            final cardWidth = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final method in methods)
                  SizedBox(
                    width: cardWidth,
                    child: PaymentCard(
                      method: method,
                      fetchFile: () => authApi.signedPaymentMethodUrl(method.id),
                      onUpload: (png) => _upload(method, png),
                      onRemoveImage: () => _confirmRemoveImage(method),
                      onEdit: () => _showForm(method: method),
                      onDelete: () => _confirmDelete(method),
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
