import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../domain/entities/app_settings.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Settings skeleton for Phase 1.
///
/// Appearance and conversion defaults are fully wired; storage and legal rows
/// are placeholders until the features they describe exist.
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
                  SettingsSection(
                    title: 'Appearance',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.brightness_6_rounded,
                        title: 'Theme',
                        value: _themeLabel(settings.themeMode),
                        onTap: () =>
                            _showThemePicker(context, settings.themeMode),
                      ),
                    ],
                  ),
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
                    title: 'Storage',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.storage_rounded,
                        title: 'Storage information',
                        onTap: () =>
                            _showComingSoon(context, 'Storage information'),
                      ),
                      SettingsTile(
                        icon: Icons.delete_sweep_rounded,
                        title: 'Clear converted files',
                        isDestructive: true,
                        onTap: () => _showComingSoon(
                          context,
                          'Clearing converted files',
                        ),
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
                      SettingsTile(
                        icon: Icons.description_rounded,
                        title: 'Terms',
                        onTap: () => _showComingSoon(context, 'Terms'),
                      ),
                      const SettingsTile(
                        icon: Icons.info_rounded,
                        title: 'About',
                        subtitle: '${AppConstants.appName} 1.0.0',
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Other',
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        value: settings.languageCode.toUpperCase(),
                        onTap: () => _showComingSoon(context, 'More languages'),
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

  String _themeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  Future<void> _showThemePicker(BuildContext context, AppThemeMode current) {
    return _showOptionSheet<AppThemeMode>(
      context: context,
      title: 'Theme',
      options: AppThemeMode.values,
      current: current,
      labelBuilder: _themeLabel,
      onSelected: controller.setThemeMode,
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
