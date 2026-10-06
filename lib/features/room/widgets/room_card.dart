import 'package:flutter/material.dart';
import 'package:m18_residences_admin/utils/entity_card.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoomCard({super.key, required this.room, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EntityCard(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.meeting_room_outlined, color: scheme.onPrimaryContainer),
      ),
      title: room.name,
      subtitle: 'Rent ${formatPeso(room.rent)} a month',
      editTooltip: 'Edit room',
      deleteTooltip: 'Delete room',
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
