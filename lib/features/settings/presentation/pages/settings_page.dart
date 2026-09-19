import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/ads_service.dart';
import '../../domain/entities/app_settings.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Settings skeleton for Phase 1.
///
/// The app is dark-only, so there is no appearance choice to offer here. Every
/// row does something: the two conversion defaults are applied to each tool,
/// and the privacy rows open the policy and the ad-consent choices.
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
                    ],
                  ),
                  SettingsSection(
                    title: 'App',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privacy Policy',
                        onTap: () => Get.toNamed<void>(AppRoutes.privacyPolicy),
                      ),
                      // Shown only where the law asks for it, so it is absent
                      // everywhere else and when ads never started.
                      if (Get.isRegistered<AdsService>())
                        ValueListenableBuilder<bool>(
                          valueListenable:
                              Get.find<AdsService>().privacyOptionsRequired,
                          builder: (BuildContext context, bool required, _) {
                            if (!required) {
                              return const SizedBox.shrink();
                            }
                            return SettingsTile(
                              icon: Icons.tune_rounded,
                              title: 'Ad privacy settings',
                              onTap: Get.find<AdsService>().showPrivacyOptions,
                            );
                          },
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
}
