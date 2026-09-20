import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/banner_ad_view.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/action_card.dart';
import '../widgets/tool_tile.dart';
import '../../../../core/i18n/translation_keys.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _Header(greeting: controller.greeting),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.pagePadding,
                  ),
                  sliver: SliverList.list(
                    children: <Widget>[
                      ActionCard(
                        icon: Icons.movie_creation_rounded,
                        title: K.toolVideoToAudio.tr,
                        description: K.toolVideoToAudioDesc.tr,
                        accentColor: AppColors.accentVideo,
                        onTap: () => _openTool(ToolMode.videoToAudio),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      ActionCard(
                        icon: Icons.swap_horiz_rounded,
                        title: K.toolAudioConvert.tr,
                        description: K.toolAudioConvertDesc.tr,
                        accentColor: AppColors.accentAudio,
                        onTap: () => _openTool(ToolMode.audioConvert),
                      ),
                      _SectionHeader(title: K.toolsSection.tr),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.pagePadding,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppDimens.spaceMd,
                      mainAxisSpacing: AppDimens.spaceMd,
                      // A fixed extent instead of an aspect ratio: tile
                      // height must not depend on screen width.
                      mainAxisExtent: ToolTile.heightFor(context),
                    ),
                    delegate: SliverChildListDelegate(<Widget>[
                      ToolTile(
                        icon: Icons.content_cut_rounded,
                        label: K.toolCut.tr,
                        accentColor: AppColors.accentVideo,
                        onTap: () => _openTool(ToolMode.cut),
                      ),
                      ToolTile(
                        icon: Icons.merge_rounded,
                        label: K.toolMerge.tr,
                        accentColor: AppColors.accentTools,
                        onTap: () => _openTool(ToolMode.merge),
                      ),
                      ToolTile(
                        icon: Icons.layers_rounded,
                        label: K.toolMix.tr,
                        accentColor: const Color(0xFF6F9BFF),
                        onTap: () => _openTool(ToolMode.mix),
                      ),
                      ToolTile(
                        icon: Icons.compress_rounded,
                        label: K.toolCompress.tr,
                        accentColor: AppColors.accentAudio,
                        onTap: () => _openTool(ToolMode.compress),
                      ),
                      ToolTile(
                        icon: Icons.auto_fix_high_rounded,
                        label: K.toolCleanup.tr,
                        accentColor: AppColors.success,
                        onTap: () => _openTool(ToolMode.cleanup),
                      ),
                      ToolTile(
                        icon: Icons.view_timeline_rounded,
                        label: K.toolArrange.tr,
                        accentColor: AppColors.accentPremium,
                        onTap: () => _openTool(ToolMode.arrange),
                      ),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.pagePadding,
                  ),
                  sliver: SliverList.list(
                    children: <Widget>[
                      // No "see all" beside the heading: the row at the foot
                      // of the list says the same thing where the reader
                      // actually runs out of files.
                      _SectionHeader(title: K.recentFiles.tr),
                      Obx(() {
                        if (!controller.hasRecentFiles) {
                          return Column(
                            children: <Widget>[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimens.spaceXl,
                                  ),
                                  child: EmptyStateView(
                                    icon: Icons.folder_open_rounded,
                                    title: K.noFilesYet.tr,
                                    message:
                                        K.noFilesYetMessage.tr,
                                  ),
                                ),
                              ),
                              const _InlineBanner(),
                            ],
                          );
                        }

                        final List<MediaFile> files = controller.recentFiles;
                        return Column(
                          children: <Widget>[
                            for (
                              int index = 0;
                              index < files.length;
                              index++
                            ) ...<Widget>[
                              _RecentFileCard(
                                file: files[index],
                                onTap: () =>
                                    _playRecentFile(files[index], files),
                              ),
                              if (index == 0) const _InlineBanner(),
                              if (index < files.length - 1)
                                const SizedBox(height: AppDimens.spaceSm),
                            ],
                            // Only when the library holds more than these
                            // few: otherwise it would promise a fuller list
                            // than the Files tab actually has.
                            if (controller.hasMoreFiles)
                              _SeeAllFilesButton(
                                total: controller.libraryCount.value,
                                shown: files.length,
                              ),
                          ],
                        );
                      }),
                      const SizedBox(height: AppDimens.spaceXxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTool(ToolMode mode) {
    Get.toNamed<void>(AppRoutes.converter, arguments: mode);
  }

  void _playRecentFile(MediaFile selected, List<MediaFile> files) {
    final int index = files.indexOf(selected);
    Get.toNamed<void>(
      AppRoutes.audioPlayer,
      arguments: <String, Object>{
        'queue': <Map<String, String>>[
          for (final MediaFile file in files)
            <String, String>{'path': file.path, 'title': file.name},
        ],
        'index': index < 0 ? 0 : index,
      },
    );
  }
}

class _RecentFileCard extends StatelessWidget {
  const _RecentFileCard({required this.file, required this.onTap});

  final MediaFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String details = <String>[
      if (file.duration case final Duration duration)
        Formatters.duration(duration),
      Formatters.fileSize(file.sizeInBytes),
      file.format.toUpperCase(),
    ].join('  ·  ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.music_note_rounded,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          Icons.play_arrow_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Sends the reader to the full library once this list stops being all of it.
///
/// Shaped like the file cards above it and sitting in their column, so it
/// reads as where the list continues rather than as a stray button.
class _SeeAllFilesButton extends StatelessWidget {
  const _SeeAllFilesButton({required this.total, required this.shown});

  /// Everything in the library, so the row can say what is waiting there.
  final int total;

  /// How many of those the list above already shows.
  final int shown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int remaining = total - shown;

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Card(
        color: colors.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.2),
            child: Icon(Icons.folder_open_rounded, color: colors.primary),
          ),
          title: Text(
            K.seeAllFiles.trParams(<String, String>{'count': '$total'}),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            K.moreInLibrary.trParams(<String, String>{
              'count': '$remaining',
            }),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: colors.primary),
          onTap: () => Get.find<ShellController>().goToFiles(),
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          BannerAdView(
            width: constraints.maxWidth.floor(),
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
          ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.spaceLg,
        AppDimens.pagePadding,
        AppDimens.spaceXl,
      ),
      child: Row(
        children: <Widget>[
          const AppLogo(size: 44),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceXl,
        bottom: AppDimens.spaceMd,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
