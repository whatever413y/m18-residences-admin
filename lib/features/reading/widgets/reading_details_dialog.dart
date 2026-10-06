import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class ReadingDetailsDialog extends StatelessWidget {
  final Reading reading;
  final String Function(int tenantId) getTenantName;
  final String Function(int roomId) getRoomName;
  final DateFormat dateFormat;

  const ReadingDetailsDialog({super.key, required this.reading, required this.getTenantName, required this.getRoomName, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.windowSize.isCompact;
    Widget row(String label, String value, {bool emphasized = false}) {
      final style = emphasized ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: 16),
            Text(
              value,
              textAlign: TextAlign.right,
              style: style?.copyWith(fontFeatures: AppTheme.tabularFigures),
            ),
          ],
        ),
      );
    }

    return Dialog(
      insetPadding: compact ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reading Details', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(getTenantName(reading.tenantId), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text('${getRoomName(reading.roomId)} · ${dateFormat.format(reading.createdAt)}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 20),
              row('Previous Reading', '${formatCount(reading.prevReading)} kWh'),
              row('Current Reading', '${formatCount(reading.currReading)} kWh'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              row('Consumption', '${formatCount(reading.consumption)} kWh', emphasized: true),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
