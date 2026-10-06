import 'package:flutter/material.dart';

/// A room or tenant in a list or grid: an avatar, a title and a subtitle, with Edit and Delete buttons.
class EntityCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// The height grids give each card (fits two lines of subtitle at 1.3× text).
  static const double gridExtent = 104;

  const EntityCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(tooltip: editTooltip, icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
              IconButton(
                tooltip: deleteTooltip,
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
