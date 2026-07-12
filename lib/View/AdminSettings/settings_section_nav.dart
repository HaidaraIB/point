import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/View/AdminSettings/settings_sections.dart';
import 'package:point/Utils/app_theme_extension.dart';

class SettingsSectionNav extends StatelessWidget {  const SettingsSectionNav({
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
    final theme = context.appTheme;
    final color = selected ? theme.accentText : theme.primaryText;
    final bg = selected ? theme.panelTint : null;
    final borderColor = selected ? theme.accentText : Colors.transparent;

    return Material(
      color: bg ?? Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: selected && !compact
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: BorderDirectional(
                    start: BorderSide(color: borderColor, width: 3),
                  ),
                )
              : null,
          padding: EdgeInsetsDirectional.fromSTEB(
            compact ? 12 : 14,
            compact ? 8 : 9,
            compact ? 12 : 10,
            compact ? 8 : 9,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: compact ? 20 : 22,
                height: compact ? 20 : 22,
                child: Center(
                  child: Icon(
                    section.icon,
                    size: compact ? 17 : 18,
                    color: color,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              if (compact)
                Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    height: 1.2,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

  BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
    color: context.appTheme.cardSurface,
    borderRadius: const BorderRadius.all(Radius.circular(12)),
    boxShadow: [
      BoxShadow(
        color: context.appTheme.shadowColor,
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _buildPageTitle(BuildContext context, {required bool compact}) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        compact ? 4 : 16,
        compact ? 0 : 4,
        compact ? 4 : 16,
        compact ? 10 : 12,
      ),
      child: Text(
        AppLocaleKeys.adminSettingsTitle.tr,
        style: TextStyle(
          fontSize: compact ? 16 : 17,
          fontWeight: FontWeight.w700,
          color: context.appTheme.primaryText,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildContentPanel(BuildContext context, Widget child) {
    return DecoratedBox(
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideNav = constraints.maxWidth >= 720;

        if (!useSideNav) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPageTitle(context, compact: true),
                SettingsSectionNav(
                  selected: selected,
                  onSelected: onSelected,
                  vertical: false,
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildContentPanel(context, content)),
              ],
            ),
          );
        }

        return SizedBox(
          height: constraints.maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 240,
                child: DecoratedBox(
                  decoration: _panelDecoration(context),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPageTitle(context, compact: false),
                          SettingsSectionNav(
                            selected: selected,
                            onSelected: onSelected,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _buildContentPanel(context, content)),
            ],
          ),
        );
      },
    );
  }
}
