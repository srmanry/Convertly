import 'package:convertly/features/shell/presentation/controllers/shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShellController', () {
    test('starts on the Home tab', () {
      expect(ShellController().currentTab.value, ShellTab.home);
    });

    test('changeTab maps a navigation index onto a tab', () {
      final ShellController controller = ShellController()..changeTab(2);

      expect(controller.currentTab.value, ShellTab.tools);
      expect(controller.currentIndex, 2);
    });

    test('back from a secondary tab returns Home instead of exiting', () {
      final ShellController controller = ShellController()..goToFiles();

      final bool mayExit = controller.handleBackPressed();

      expect(mayExit, isFalse);
      expect(controller.currentTab.value, ShellTab.home);
    });

    test('back from Home allows the app to exit', () {
      expect(ShellController().handleBackPressed(), isTrue);
    });
  });
}
