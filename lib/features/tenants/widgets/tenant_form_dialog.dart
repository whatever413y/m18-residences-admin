import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class TenantFormDialog extends StatefulWidget {
  final Tenant? tenant;
  final List<Room> rooms;
  final bool? isEditing;

  const TenantFormDialog({super.key, this.tenant, required this.rooms, this.isEditing});

  @override
  State<TenantFormDialog> createState() => _TenantFormDialogState();
}

class _TenantFormDialogState extends State<TenantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedRoomId;
  DateTime? _selectedJoinDate;
  bool? _isActive;
  bool? _isEditing;
  final _dateFormat = DateFormat('MMMM d, y');

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing ?? false;
    _nameController.text = widget.tenant?.name ?? '';
    _selectedRoomId = widget.tenant?.roomId.toString();
    // New tenants default to joining today; "Pick Date" changes it.
    _selectedJoinDate = widget.tenant?.joinDate ?? DateUtils.dateOnly(DateTime.now());
    _isActive = widget.tenant?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final name = _nameController.text.trim();
    final roomId = int.parse(_selectedRoomId!);
    final joinDate = _selectedJoinDate!;
    final isActive = _isActive;

    Navigator.of(context).pop({'name': name, 'roomId': roomId, 'joinDate': joinDate, 'isActive': isActive});
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tenant != null;
    return AppModal(
      leading: AppModal.icon(context, Icons.person_outline),
      title: isEditing ? 'Edit Tenant' : 'Add New Tenant',
      subtitle: isEditing ? widget.tenant!.name : 'The name is also their account ID',
      actions: _buildActions(context, isEditing),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isEditing!) ...[_buildActiveToggle(), const SizedBox(height: 12)],
          _buildNameField(),
          const SizedBox(height: 12),
          _buildRoomDropdown(),
          const SizedBox(height: 12),
          _buildJoinDatePicker(context),
        ],
      ),
    );
  }

  Widget _buildActiveToggle() {
    return SwitchListTile(
      title: Text(_isActive! ? 'Active' : 'Inactive'),
      value: _isActive!,
      onChanged: (val) {
        setState(() {
          _isActive = val;
        });
      },
    );
  }

  Widget _buildNameField() {
    return CustomTextFormField(
      controller: _nameController,
      labelText: 'Tenant',
      semanticsId: 'tenant-name',
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter tenant' : null,
      onFieldSubmitted: (_) => _submit(),
      prefixIcon: const Icon(Icons.person_outline),
    );
  }

  Widget _buildRoomDropdown() {
    return CustomDropdownForm<String>(
      label: 'Room',
      semanticsId: 'tenant-room',
      value: _selectedRoomId,
      items: widget.rooms.map((room) => DropdownMenuItem(value: room.id.toString(), child: Text(room.name))).toList(),
      onChanged: (value) => setState(() => _selectedRoomId = value),
      validator: (value) => value == null || value.isEmpty ? 'Please select a room' : null,
    );
  }

  Widget _buildJoinDatePicker(BuildContext context) {
    return FormField<DateTime>(
      validator: (value) => _selectedJoinDate == null ? 'Please pick a join date' : null,
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_selectedJoinDate == null ? 'Select Join Date' : 'Joined: ${_dateFormat.format(_selectedJoinDate!)}')),
                Semantics(
                  container: true,
                  identifier: 'tenant-pick-date',
                  child: TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedJoinDate ?? now,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedJoinDate = picked;
                          formFieldState.didChange(picked);
                        });
                      }
                    },
                    child: const Text('Pick Date'),
                  ),
                ),
              ],
            ),
            if (formFieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 10),
                child: Text(formFieldState.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isEditing) {
    return [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      Semantics(
        container: true,
        identifier: 'tenant-save',
        child: FilledButton(onPressed: _submit, child: Text(isEditing ? 'Save' : 'Add')),
      ),
    ];
  }
}
