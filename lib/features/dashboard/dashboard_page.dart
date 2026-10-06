import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_state.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_details_dialog.dart';
import 'package:m18_residences_admin/features/dashboard/dashboard_stats.dart';
import 'package:m18_residences_admin/features/shell/admin_shell.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The admin's start page: this month's billed, collected and outstanding amounts, occupancy, the bills that need
/// attention and a year of billed vs collected.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Recomputed only when the billing data changes.
  (BillingLoaded, DashboardStats)? _cached;

  DashboardStats _stats(BillingLoaded state) {
    final cached = _cached;
    if (cached != null && identical(cached.$1, state)) return cached.$2;
    final stats = DashboardStats.from(bills: state.bills, rooms: state.rooms, tenants: state.tenants);
    _cached = (state, stats);
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final billingBloc = context.read<BillingBloc>();
    return Scaffold(
      appBar: AdminAppBar(title: 'Dashboard', onRefresh: () => billingBloc.add(LoadBills())),
      body: BlocBuilder<BillingBloc, BillingState>(
        buildWhen: (_, state) => state is BillingLoading || state is BillingLoaded || state is BillingError,
        builder: (context, state) {
          final data = state is BillingLoaded ? state : AdminShell.of(context).billing;
          if (state is BillingError && data == null) return ErrorView(message: state.message, onRetry: () => billingBloc.add(LoadBills()));
          if (data == null) return const Center(child: CircularProgressIndicator());
          final stats = _stats(data);
          final compact = context.windowSize.isCompact;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: 20),
            child: ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(stats: stats),
                  const SizedBox(height: 20),
                  _Kpis(stats: stats),
                  const SizedBox(height: 24),
                  ResponsiveBuilder(
                    compact: (_) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Attention(stats: stats, data: data),
                        const SizedBox(height: 24),
                        _RevenueCard(stats: stats),
                      ],
                    ),
                    expanded: (_) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _Attention(stats: stats, data: data),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 6, child: _RevenueCard(stats: stats)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DashboardStats stats;

  const _Header({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat.yMMMM().format(stats.month), style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          '${stats.billCount} ${stats.billCount == 1 ? 'bill' : 'bills'} · ${stats.activeTenants} active tenants · '
          '${stats.unpaidCount} unpaid, ${stats.verifyingCount} to verify, ${stats.paidCount} paid',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  final DashboardStats stats;

  const _Kpis({required this.stats});

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);
    final collectedShare = stats.billed == 0 ? 0.0 : stats.collected / stats.billed;
    final occupancy = stats.roomCount == 0 ? 0.0 : stats.occupiedRooms / stats.roomCount;
    final cards = [
      _Kpi(icon: Icons.receipt_long_outlined, label: 'Billed', value: formatPeso(stats.billed), note: '${stats.billCount} bills this month'),
      _Kpi(
        icon: Icons.savings_outlined,
        label: 'Collected',
        value: formatPeso(stats.collected),
        note: '${(collectedShare * 100).round()}% of billed',
        progress: collectedShare,
        progressColor: status.onPaid,
      ),
      _Kpi(
        icon: Icons.pending_actions_outlined,
        label: 'Outstanding',
        value: formatPeso(stats.outstanding),
        note: '${stats.unpaidCount} unpaid · ${stats.verifyingCount} to verify',
        accent: stats.outstanding > 0 ? status.onUnpaid : null,
      ),
      _Kpi(
        icon: Icons.meeting_room_outlined,
        label: 'Occupancy',
        value: '${stats.occupiedRooms}/${stats.roomCount}',
        note: '${(occupancy * 100).round()}% of rooms occupied',
        progress: occupancy,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across on desktops, two on tablets and phones; the cards of a row share its height.
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        return Column(
          children: [
            for (var start = 0; start < cards.length; start += columns) ...[
              if (start > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < start + columns && i < cards.length; i++) ...[
                      if (i > start) const SizedBox(width: gap),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;
  final double? progress;
  final Color? progressColor;
  final Color? accent;

  const _Kpi({required this.icon, required this.label, required this.value, required this.note, this.progress, this.progressColor, this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(color: accent, fontFeatures: AppTheme.tabularFigures),
              ),
            ),
            const SizedBox(height: 8),
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: progressColor ?? scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(note, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Payments to verify, then unpaid bills; each opens the bill.
class _Attention extends StatelessWidget {
  final DashboardStats stats;
  final BillingLoaded data;

  const _Attention({required this.stats, required this.data});

  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = AdminShell.of(context);
    final tenants = {for (final t in data.tenants) t.id: t};
    final rooms = {for (final r in data.rooms) r.id: r};
    final bills = stats.attention.take(_shown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          title: 'Needs attention',
          subtitle: stats.attention.isEmpty ? null : '${stats.attention.length} bills to verify or collect',
          trailing: stats.verifyingCount > 0
              ? TextButton(onPressed: () => shell.select(AdminTab.verify), child: const Text('Verify payments'))
              : null,
        ),
        Card(
          child: bills.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: EmptyState(icon: Icons.task_alt, title: 'All caught up', message: 'Every bill is paid.'),
                )
              : Column(
                  children: [
                    for (final (i, bill) in bills.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: StatusColors.of(context).forStatus(bill.status).$1,
                          child: Icon(BillStatusChip.icon(bill.status), color: StatusColors.of(context).forStatus(bill.status).$2, size: 20),
                        ),
                        title: Text(tenants[bill.tenantId]?.name ?? 'Unknown tenant'),
                        subtitle: Text('${DateFormat.yMMMM().format(bill.createdAt)} · ${bill.status.label}'),
                        trailing: MoneyText(bill.totalAmount, style: theme.textTheme.titleSmall),
                        onTap: () => showBillDetails(context, bill, tenants: tenants, rooms: rooms),
                      ),
                    ],
                    if (stats.attention.length > _shown) ...[
                      const Divider(),
                      TextButton(onPressed: () => shell.select(AdminTab.billing), child: const Text('See all bills')),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Billed vs collected over twelve months as paired bars (plain widgets; each month has a tooltip).
class _RevenueCard extends StatelessWidget {
  final DashboardStats stats;

  const _RevenueCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final billedColor = scheme.brightness == Brightness.light ? const Color(0xFF99F6E4) : const Color(0xFF115E59);
    final collectedColor = scheme.primary;
    final highest = stats.history.map((m) => m.billed).fold(0, math.max);
    final yearBilled = stats.history.fold(0, (sum, m) => sum + m.billed);
    final yearCollected = stats.history.fold(0, (sum, m) => sum + m.collected);

    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(title: 'Last 12 months', subtitle: '${formatPeso(yearCollected)} collected of ${formatPeso(yearBilled)} billed'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 16, runSpacing: 4, children: [legend(billedColor, 'Billed'), legend(collectedColor, 'Collected')]),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in stats.history)
                        Expanded(
                          child: Tooltip(
                            message: '${DateFormat.yMMM().format(m.month)}\nBilled ${formatPeso(m.billed)}\nCollected ${formatPeso(m.collected)}',
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _bar(m.billed, highest, billedColor),
                                      const SizedBox(width: 2),
                                      _bar(m.collected, highest, collectedColor),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat.MMM().format(m.month).substring(0, 1),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(int value, int highest, Color color) {
    return Flexible(
      child: FractionallySizedBox(
        heightFactor: highest == 0 ? 0 : math.max(value / highest, value > 0 ? 0.02 : 0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}
