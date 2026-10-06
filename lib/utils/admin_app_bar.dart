import 'package:flutter/material.dart';
import 'package:m18_residences_admin/features/shell/admin_shell.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The top bar of an admin page inside the shell: its title, the page's [actions], Search and (with [onRefresh])
/// Refresh. No Back button: the shell's navigation switches pages.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onRefresh;
  final List<Widget> actions;

  const AdminAppBar({super.key, required this.title, this.onRefresh, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return CustomAppBar(
      title: title,
      showLeading: false,
      showRefresh: onRefresh != null,
      onRefresh: onRefresh,
      actions: [...actions, const AdminSearchButton()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Search over tenants and rooms (from the shell's billing data); a match opens Billing filtered to it.
class AdminSearchButton extends StatelessWidget {
  const AdminSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = context.windowSize.isCompact;
    // The results are built in the search view's own route, outside the shell: look the shell up here.
    final shell = AdminShell.of(context);
    return SearchAnchor(
      isFullScreen: compact,
      viewHintText: 'Search tenants and rooms',
      viewConstraints: const BoxConstraints(minWidth: 360, maxWidth: 440, maxHeight: 520),
      builder: (context, controller) => IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: controller.openView),
      suggestionsBuilder: (context, controller) => _results(context, shell, controller),
    );
  }

  List<Widget> _results(BuildContext context, AdminShellState shell, SearchController controller) {
    final data = shell.billing;
    if (data == null) return const [ListTile(title: Text('Loading...'))];

    final query = controller.text.trim().toLowerCase();
    bool matches(String name) => query.isEmpty || name.toLowerCase().contains(query);
    final rooms = {for (final r in data.rooms) r.id: r};
    final tenants = data.tenants.where((t) => matches(t.name)).toList()
      // Active tenants first, then by name.
      ..sort((a, b) => a.isActive != b.isActive ? (a.isActive ? -1 : 1) : a.name.compareTo(b.name));
    final matchedRooms = data.rooms.where((r) => matches(r.name)).toList();

    void open({int? tenantId, int? roomId}) {
      controller.closeView('');
      shell.showBills(tenantId: tenantId, roomId: roomId);
    }

    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );

    return [
      if (tenants.isNotEmpty) header('Tenants'),
      for (final t in tenants)
        ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              t.name.isEmpty ? '?' : t.name[0],
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(t.name),
          subtitle: Text('${rooms[t.roomId]?.name ?? 'No room'} · ${t.isActive ? 'Active' : 'Inactive'}'),
          trailing: const Icon(Icons.receipt_long_outlined),
          onTap: () => open(tenantId: t.id),
        ),
      if (matchedRooms.isNotEmpty) header('Rooms'),
      for (final r in matchedRooms)
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.meeting_room_outlined)),
          title: Text(r.name),
          subtitle: Text('Rent ${formatPeso(r.rent)}'),
          trailing: const Icon(Icons.receipt_long_outlined),
          onTap: () => open(roomId: r.id),
        ),
      if (tenants.isEmpty && matchedRooms.isEmpty) const ListTile(leading: Icon(Icons.search_off), title: Text('No tenants or rooms match')),
    ];
  }
}
