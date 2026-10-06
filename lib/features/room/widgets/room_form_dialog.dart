import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class RoomFormDialog extends StatefulWidget {
  final Room? room;

  const RoomFormDialog({super.key, this.room});

  @override
  State<RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _rentController = TextEditingController(text: widget.room != null ? widget.room!.rent.toString() : '');
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final data = {'name': _nameController.text.trim(), 'rent': int.parse(_rentController.text.trim())};
      Navigator.of(context).pop(data);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.room != null;
    return AppModal(
      leading: AppModal.icon(context, Icons.meeting_room_outlined),
      title: isEditing ? 'Edit Room' : 'Add New Room',
      subtitle: isEditing ? widget.room!.name : 'Name and monthly rent',
      actions: _buildActions(),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [_buildNameField(), const SizedBox(height: 12), _buildRentField()]),
    );
  }

  Widget _buildNameField() {
    return CustomTextFormField(
      controller: _nameController,
      labelText: 'Room Name',
      semanticsId: 'room-name',
      textInputAction: TextInputAction.next,
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter room name' : null,
      prefixIcon: const Icon(Icons.meeting_room_outlined),
    );
  }

  Widget _buildRentField() {
    return CustomTextFormField(
      controller: _rentController,
      labelText: 'Rent',
      semanticsId: 'room-rent',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      validator: (val) {
        final parsed = int.tryParse(val ?? '');
        if (parsed == null || parsed < 0) {
          return 'Enter a valid rent amount';
        }
        return null;
      },
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          '₱',
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  List<Widget> _buildActions() {
    final isEditing = widget.room != null;

    return [
      TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
      Semantics(
        container: true,
        identifier: 'room-save',
        child: FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save' : 'Add')),
      ),
    ];
  }
}
