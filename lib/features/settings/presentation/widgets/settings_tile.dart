import 'package:flutter/material.dart';

/// A single settings row with a leading icon and optional trailing value.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color foreground = isDestructive ? colors.error : colors.onSurface;

    return ListTile(
      leading: Icon(icon, color: isDestructive ? colors.error : colors.primary),
      title: Text(title, style: TextStyle(color: foreground)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (value == null
              ? (onTap == null ? null : const Icon(Icons.chevron_right_rounded))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                )),
      onTap: onTap,
    );
  }
}
