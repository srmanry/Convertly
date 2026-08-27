import 'package:get/get.dart';

/// Tabs hosted by the bottom navigation shell.
enum ShellTab { home, files, tools, settings }

/// Owns which tab is visible and the Android back-button contract.
class ShellController extends GetxController {
  final Rx<ShellTab> currentTab = ShellTab.home.obs;

  int get currentIndex => currentTab.value.index;

  void changeTab(int index) => currentTab.value = ShellTab.values[index];

  void goToFiles() => currentTab.value = ShellTab.files;

  /// Back on a secondary tab returns to Home instead of closing the app.
  /// Returns `true` when the app may exit.
  bool handleBackPressed() {
    if (currentTab.value == ShellTab.home) {
      return true;
    }
    currentTab.value = ShellTab.home;
    return false;
  }
}
