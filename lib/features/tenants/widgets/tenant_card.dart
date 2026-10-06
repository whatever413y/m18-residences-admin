import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/utils/entity_card.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class TenantCard extends StatelessWidget {
  final Tenant tenant;
  final Room room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TenantCard({super.key, required this.tenant, required this.room, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EntityCard(
      leading: CircleAvatar(
        backgroundColor: tenant.isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          tenant.name.isEmpty ? '?' : tenant.name[0],
          style: TextStyle(
            color: tenant.isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: tenant.name,
      subtitle: '${room.name} · Joined ${DateFormat('MMM d, y').format(tenant.joinDate)}${tenant.isActive ? '' : ' · Inactive'}',
      editTooltip: 'Edit tenant',
      deleteTooltip: 'Delete tenant',
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
