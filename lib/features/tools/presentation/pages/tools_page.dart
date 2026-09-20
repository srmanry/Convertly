import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/action_card.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Tools dashboard. Each card is wired up in its own later phase.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_Tool> tools = <_Tool>[
      _Tool(
        icon: Icons.movie_creation_rounded,
        title: K.toolVideoToAudio.tr,
        description: K.toolVideoToAudioDesc.tr,
        color: AppColors.accentVideo,
        mode: ToolMode.videoToAudio,
      ),
      _Tool(
        icon: Icons.swap_horiz_rounded,
        title: K.toolAudioConvert.tr,
        description: K.toolAudioConvertDesc.tr,
        color: AppColors.accentAudio,
        mode: ToolMode.audioConvert,
      ),
      _Tool(
        icon: Icons.content_cut_rounded,
        title: K.toolCut.tr,
        description: K.toolCutDesc.tr,
        color: AppColors.accentTools,
        mode: ToolMode.cut,
      ),
      _Tool(
        icon: Icons.merge_rounded,
        title: K.toolMerge.tr,
        description: K.toolMergeDesc.tr,
        color: AppColors.accentTools,
        mode: ToolMode.merge,
      ),
      _Tool(
        icon: Icons.compress_rounded,
        title: K.toolCompress.tr,
        description: K.toolCompressDesc.tr,
        color: AppColors.accentTools,
        mode: ToolMode.compress,
      ),
      _Tool(
        icon: Icons.layers_rounded,
        title: K.toolMix.tr,
        description: K.toolMixDesc.tr,
        color: AppColors.accentAudio,
        mode: ToolMode.mix,
      ),
      _Tool(
        icon: Icons.view_timeline_rounded,
        title: K.toolArrange.tr,
        description: K.toolArrangeDesc.tr,
        color: AppColors.accentAudio,
        mode: ToolMode.arrange,
      ),
      _Tool(
        icon: Icons.auto_fix_high_rounded,
        title: K.toolCleanup.tr,
        description: K.toolCleanupDesc.tr,
        color: AppColors.accentAudio,
        mode: ToolMode.cleanup,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(K.toolsSection.tr)),
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
