import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../files/presentation/controllers/files_controller.dart';
import '../../../files/presentation/pages/files_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../music_library/presentation/pages/music_library_page.dart';
import '../../../../core/widgets/banner_ad_view.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../controllers/shell_controller.dart';

/// Root scaffold hosting the four primary destinations.
///
/// Tabs are kept alive with an [IndexedStack] so switching does not rebuild or
/// lose scroll position.
class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Back leaves a selection before it changes tab, matching how Android
        // contextual action bars behave.
        if (Get.isRegistered<FilesController>()) {
          final FilesController files = Get.find<FilesController>();
          if (files.isSelectionMode) {
            files.clearSelection();
            return;
          }
        }
        if (controller.handleBackPressed()) {
          Navigator.of(context).maybePop();
        }
      },
      child: Obx(
        () => Scaffold(
          body: IndexedStack(
            index: controller.currentIndex,
            children: const <Widget>[
              HomePage(),
              FilesPage(),
              MusicLibraryPage(),
              SettingsPage(showBackButton: false),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Home owns its ad placement beside Recent Files. Other tabs
              // keep the shared banner above the dock.
              if (controller.currentTab.value != ShellTab.home)
                const BannerAdView(),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: _BottomDock(
                  selectedIndex: controller.currentIndex,
                  onSelected: controller.changeTab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<_DockDestination> _destinations = <_DockDestination>[
    _DockDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _DockDestination(
      label: 'Files',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    _DockDestination(
      label: 'Player',
      icon: Icons.play_circle_outline_rounded,
      selectedIcon: Icons.play_circle_filled_rounded,
    ),
    _DockDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme colors = theme.colorScheme;
    final BorderRadius radius = BorderRadius.circular(AppDimens.radiusXl);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: GlassSurface(
        blur: 26,
        borderRadius: radius,
        topRim: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.48 : 0.62,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceXs),
            child: Row(
              children: <Widget>[
                for (int index = 0; index < _destinations.length; index++)
                  Expanded(
                    child: _BottomDockItem(
                      destination: _destinations[index],
                      selected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomDockItem extends StatelessWidget {
  const _BottomDockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DockDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color foreground = selected
        ? colors.primary
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 58,
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.15 : 0.1,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (Widget child, Animation<double> value) =>
                      FadeTransition(
                        opacity: value,
                        child: ScaleTransition(scale: value, child: child),
                      ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    key: ValueKey<bool>(selected),
                    color: foreground,
                    size: AppDimens.iconMd,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDestination {
  const _DockDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
