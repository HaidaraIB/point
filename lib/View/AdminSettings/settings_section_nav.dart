import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/AdminSettings/settings_sections.dart';
import 'package:point/View/Shared/responsive.dart';

class SettingsSectionNav extends StatelessWidget {
  const SettingsSectionNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.vertical = true,
  });

  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final section in kSettingsSections)
        _SettingsSectionTile(
          section: section,
          selected: section == selected,
          compact: !vertical,
          onTap: () => onSelected(section),
        ),
    ];

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const SizedBox(height: 4),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SettingsSectionTile extends StatelessWidget {
  const _SettingsSectionTile({
    required this.section,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.primaryfontColor;
    final bg = selected ? AppColors.primary.withValues(alpha: 0.08) : null;

    return Material(
      color: bg ?? Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(section.icon, size: 20, color: color),
              const SizedBox(width: 10),
              if (compact)
                Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop: side nav + content. Mobile: horizontal nav + content.
/// Same tile style on every breakpoint — only layout changes.
class SettingsSectionLayout extends StatelessWidget {
  const SettingsSectionLayout({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.content,
  });

  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionNav(
            selected: selected,
            onSelected: onSelected,
            vertical: false,
          ),
          const SizedBox(height: 20),
          Expanded(child: content),
        ],
      ),
      desktop: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: SettingsSectionNav(
              selected: selected,
              onSelected: onSelected,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: content),
        ],
      ),
    );
  }
}
