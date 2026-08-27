import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/action_card.dart';
import '../widgets/tool_tile.dart';

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
                        title: 'Video to Audio',
                        description: 'Extract audio from a video',
                        accentColor: AppColors.accentVideo,
                        onTap: () => _openTool(ToolMode.videoToAudio),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      ActionCard(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Audio Converter',
                        description: 'Convert audio between formats',
                        accentColor: AppColors.accentAudio,
                        onTap: () => _openTool(ToolMode.audioConvert),
                      ),
                      const _SectionHeader(title: 'Tools'),
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
                      // A fixed extent instead of an aspect ratio: tile
                      // height must not depend on screen width.
                      mainAxisExtent: ToolTile.heightFor(context),
                    ),
                    delegate: SliverChildListDelegate(<Widget>[
                      ToolTile(
                        icon: Icons.content_cut_rounded,
                        label: 'Audio Cutter',
                        accentColor: AppColors.accentTools,
                        onTap: () => _openTool(ToolMode.cut),
                      ),
                      ToolTile(
                        icon: Icons.merge_rounded,
                        label: 'Audio Merger',
                        accentColor: AppColors.accentTools,
                        onTap: () => _openTool(ToolMode.merge),
                      ),
                      ToolTile(
                        icon: Icons.compress_rounded,
                        label: 'Audio Compressor',
                        accentColor: AppColors.accentTools,
                        onTap: () => _openTool(ToolMode.compress),
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
                      _SectionHeader(
                        title: 'Recent Files',
                        action: TextButton(
                          onPressed: () =>
                              Get.find<ShellController>().goToFiles(),
                          child: const Text('See all'),
                        ),
                      ),
                      Obx(() {
                        if (!controller.hasRecentFiles) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimens.spaceXl,
                              ),
                              child: EmptyStateView(
                                icon: Icons.library_music_outlined,
                                title: 'No files yet',
                                message:
                                    'Your converted files will appear here.',
                              ),
                            ),
                          );
                        }
                        // Populated in Phase 5 once the media library exists.
                        return Card(
                          child: Column(
                            children: <Widget>[
                              for (final MediaFile file
                                  in controller.recentFiles)
                                ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.music_note_rounded),
                                  ),
                                  title: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      file.format.toUpperCase(),
                                      Formatters.fileSize(file.sizeInBytes),
                                      if (file.duration != null)
                                        Formatters.duration(file.duration!),
                                    ].join(' • '),
                                  ),
                                  trailing: Text(
                                    Formatters.date(file.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  onTap: () =>
                                      Get.find<ShellController>().goToFiles(),
                                ),
                            ],
                          ),
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
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Get.toNamed<void>(AppRoutes.settings),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceXl,
        bottom: AppDimens.spaceMd,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );
  }
}
