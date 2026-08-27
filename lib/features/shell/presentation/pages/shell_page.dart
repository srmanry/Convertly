import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../files/presentation/controllers/files_controller.dart';
import '../../../files/presentation/pages/files_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../tools/presentation/pages/tools_page.dart';
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
              ToolsPage(),
              SettingsPage(showBackButton: false),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: controller.currentIndex,
            onDestinationSelected: controller.changeTab,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Files',
              ),
              NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build_rounded),
                label: 'Tools',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
