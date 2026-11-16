import 'package:material_ui/material_ui.dart';

class CustomAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomAddButton({super.key, required this.onPressed, required this.label, this.icon = Icons.add, this.backgroundColor, this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).floatingActionButtonTheme;

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? theme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.foregroundColor,
      icon: Icon(icon, color: foregroundColor ?? theme.foregroundColor),
      label: Text(label, style: TextStyle(color: foregroundColor ?? theme.foregroundColor)),
    );
  }
}
