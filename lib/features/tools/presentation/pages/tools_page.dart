import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/action_card.dart';

/// Tools dashboard. Each card is wired up in its own later phase.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_Tool> tools = <_Tool>[
      const _Tool(
        icon: Icons.movie_creation_rounded,
        title: 'Video to Audio',
        description: 'Extract audio from a video',
        color: AppColors.accentVideo,
        mode: ToolMode.videoToAudio,
      ),
      const _Tool(
        icon: Icons.swap_horiz_rounded,
        title: 'Audio Converter',
        description: 'Convert audio between formats',
        color: AppColors.accentAudio,
        mode: ToolMode.audioConvert,
      ),
      const _Tool(
        icon: Icons.content_cut_rounded,
        title: 'Audio Cutter',
        description: 'Trim a section out of an audio file',
        color: AppColors.accentTools,
        mode: ToolMode.cut,
      ),
      const _Tool(
        icon: Icons.merge_rounded,
        title: 'Audio Merger',
        description: 'Join several audio files into one',
        color: AppColors.accentTools,
        mode: ToolMode.merge,
      ),
      const _Tool(
        icon: Icons.compress_rounded,
        title: 'Audio Compressor',
        description: 'Reduce the size of an audio file',
        color: AppColors.accentTools,
        mode: ToolMode.compress,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimens.maxContentWidth,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.spaceSm,
              AppDimens.pagePadding,
              AppDimens.spaceXxl,
            ),
            itemCount: tools.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimens.spaceMd),
            itemBuilder: (BuildContext context, int index) {
              final _Tool tool = tools[index];
              return ActionCard(
                icon: tool.icon,
                title: tool.title,
                description: tool.description,
                accentColor: tool.color,
                onTap: () => Get.toNamed<void>(
                  AppRoutes.converter,
                  arguments: tool.mode,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.mode,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final ToolMode mode;
}
