import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// A reading's details (shown with [showAppModal]): who and when, the meter values and the consumption.
class ReadingDetailsDialog extends StatelessWidget {
  final Reading reading;
  final String Function(int tenantId) getTenantName;
  final String Function(int roomId) getRoomName;
  final DateFormat dateFormat;

  const ReadingDetailsDialog({super.key, required this.reading, required this.getTenantName, required this.getRoomName, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return AppModal(
      overline: 'Reading Details',
      title: getTenantName(reading.tenantId),
      subtitle: '${getRoomName(reading.roomId)} · ${dateFormat.format(reading.createdAt)}',
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Previous Reading', '${formatCount(reading.prevReading)} kWh'),
          row('Current Reading', '${formatCount(reading.currReading)} kWh'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          row('Consumption', '${formatCount(reading.consumption)} kWh', emphasized: true),
        ],
      ),
    );
  }
}
