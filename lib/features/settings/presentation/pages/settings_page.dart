import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/ad_free_button.dart';
import '../../domain/entities/app_settings.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Settings skeleton for Phase 1.
///
/// The app is dark-only, so there is no appearance choice to offer here.
/// Conversion defaults are fully wired; storage and legal rows are
/// placeholders until the features they describe exist.
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: showBackButton,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Obx(() {
              final AppSettings settings = controller.settings.value;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  0,
                  AppDimens.pagePadding,
                  AppDimens.spaceXxl,
                ),
                children: <Widget>[
                  // No Appearance section: the app is dark-only, so there is
                  // no theme choice to show.
                  SettingsSection(
                    title: 'Conversion',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.audio_file_rounded,
                        title: 'Default output format',
                        value: settings.defaultOutputFormat.label,
                        onTap: () => _showFormatPicker(
                          context,
                          settings.defaultOutputFormat,
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.high_quality_rounded,
                        title: 'Default audio quality',
                        value: settings.defaultAudioQuality.label,
                        onTap: () => _showQualityPicker(
                          context,
                          settings.defaultAudioQuality,
                        ),
                      ),
                      SettingsTile(
                        icon: Icons.folder_rounded,
                        title: 'Output folder',
                        subtitle: settings.outputFolder ?? 'App default folder',
                        onTap: () =>
                            _showComingSoon(context, 'Custom output folder'),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Ads',
                    children: const <Widget>[
                      Padding(
                        padding: EdgeInsets.all(AppDimens.spaceLg),
                        child: AdFreeButton(),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Storage',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.storage_rounded,
                        title: 'Storage information',
                        subtitle: 'What the app is keeping on this device',
                        onTap: () => Get.toNamed<void>(AppRoutes.storage),
                      ),
                      SettingsTile(
                        icon: Icons.delete_sweep_rounded,
                        title: 'Clear converted files',
                        isDestructive: true,
                        // Deleting everything is confirmed on the storage
                        // screen, where the figure it frees is in view.
                        onTap: () => Get.toNamed<void>(AppRoutes.storage),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'App',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.star_rounded,
                        title: 'Rate App',
                        onTap: () => _showComingSoon(context, 'Rating'),
                      ),
                      SettingsTile(
                        icon: Icons.share_rounded,
                        title: 'Share App',
                        onTap: () => _showComingSoon(context, 'Sharing'),
                      ),
                      SettingsTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privacy Policy',
                        onTap: () => _showComingSoon(context, 'Privacy Policy'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _showFormatPicker(BuildContext context, AudioFormat current) {
    return _showOptionSheet<AudioFormat>(
      context: context,
      title: 'Default output format',
      options: AudioFormat.values,
      current: current,
      labelBuilder: (AudioFormat format) => format.label,
      onSelected: controller.setDefaultOutputFormat,
    );
  }

  Future<void> _showQualityPicker(BuildContext context, AudioQuality current) {
    return _showOptionSheet<AudioQuality>(
      context: context,
      title: 'Default audio quality',
      options: AudioQuality.values,
      current: current,
      labelBuilder: (AudioQuality quality) => quality.label,
      onSelected: controller.setDefaultAudioQuality,
    );
  }

  Future<void> _showOptionSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T current,
    required String Function(T value) labelBuilder,
    required Future<void> Function(T value) onSelected,
  }) async {
    final T? picked = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              RadioGroup<T>(
                groupValue: current,
                onChanged: (T? value) => Navigator.of(sheetContext).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final T option in options)
                      RadioListTile<T>(
                        value: option,
                        title: Text(labelBuilder(option)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != current) {
      await onSelected(picked);
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in a later update.')),
    );
  }
}
