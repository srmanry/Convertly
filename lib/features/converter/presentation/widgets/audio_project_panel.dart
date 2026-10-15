import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/routes/app_routes.dart';
import '../../domain/entities/audio_project.dart';
import '../controllers/converter_controller.dart';

String projectStatusLabel(AudioProjectStatus status) => switch (status) {
  AudioProjectStatus.draft => K.projectDraft.tr,
  AudioProjectStatus.completed => K.projectCompleted.tr,
  AudioProjectStatus.cancelled => K.projectCancelled.tr,
};

class AudioProjectStatusBadge extends StatelessWidget {
  const AudioProjectStatusBadge({required this.status, super.key});

  final AudioProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    final IconData icon = switch (status) {
      AudioProjectStatus.draft => Icons.edit_note_rounded,
      AudioProjectStatus.completed => Icons.check_circle_outline_rounded,
      AudioProjectStatus.cancelled => Icons.cancel_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              projectStatusLabel(status),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioProjectPanel extends StatelessWidget {
  const AudioProjectPanel({
    required this.controller,
    required this.onSaveLater,
    required this.onCancel,
    super.key,
  });

  final ConverterController controller;
  final VoidCallback onSaveLater;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Obx(() {
    final bool saving = controller.isSavingProject.value;
    final String error = controller.projectError.value;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AudioProjectStatusBadge(status: controller.projectStatus.value),
              Text(
                saving || controller.projectNeedsSave.value
                    ? K.projectSaving.tr
                    : error.isNotEmpty
                    ? K.projectNotSaved.tr
                    : K.projectAutoSaved.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            children: <Widget>[
              TextButton.icon(
                onPressed: saving ? null : onSaveLater,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(K.projectSaveLater.tr),
              ),
              TextButton.icon(
                onPressed: saving ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(K.projectCancel.tr),
              ),
            ],
          ),
          if (error.isNotEmpty)
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  });
}

Future<void> showAudioProjects(
  BuildContext context,
  ConverterController controller,
) async {
  if (!await controller.saveProject() || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _AudioProjectsSheet(controller: controller),
    ),
  );
}

class _AudioProjectsSheet extends StatefulWidget {
  const _AudioProjectsSheet({required this.controller});

  final ConverterController controller;

  @override
  State<_AudioProjectsSheet> createState() => _AudioProjectsSheetState();
}

class _AudioProjectsSheetState extends State<_AudioProjectsSheet> {
  AudioProjectStatus _status = AudioProjectStatus.draft;
  bool _opening = false;

  Future<void> _open(AudioProject? project) async {
    if (_opening) return;
    setState(() => _opening = true);
    final bool opened = project == null
        ? await widget.controller.newProject()
        : await widget.controller.openProject(project);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConverterController controller = widget.controller;
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    K.projectSavedProjects.tr,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: K.cancel.tr,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              controller.mode.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _opening ? null : () => _open(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(K.projectNew.tr),
            ),
            const SizedBox(height: 16),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final AudioProjectStatus status
                      in AudioProjectStatus.values)
                    ChoiceChip(
                      label: Text(
                        '${projectStatusLabel(status)} · ${controller.projectStore!.projects.where((AudioProject p) => p.mode == controller.mode && p.status == status).length}',
                      ),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                      showCheckmark: false,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                final List<AudioProject> projects = controller
                    .projectStore!
                    .projects
                    .where(
                      (AudioProject p) =>
                          p.mode == controller.mode && p.status == _status,
                    )
                    .toList();
                if (controller.projectStore!.loadFailed) {
                  return Center(child: Text(K.projectLoadFailed.tr));
                }
                if (projects.isEmpty) {
                  return Center(
                    child: Text(
                      K.projectNone.tr,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final AudioProject project = projects[index];
                    return Card(
                      child: ListTile(
                        onTap: _opening ? null : () => _open(project),
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(
                          project.fileName.isEmpty
                              ? project.mode.title
                              : project.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${K.projectClipCount.trParams(<String, String>{'count': '${project.sources.length}'})} · ${MaterialLocalizations.of(context).formatMediumDate(project.updatedAt.toLocal())}',
                              ),
                              const SizedBox(height: 8),
                              AudioProjectStatusBadge(status: project.status),
                            ],
                          ),
                        ),
                        trailing:
                            project.status == AudioProjectStatus.completed &&
                                project.outputPath != null
                            ? IconButton(
                                tooltip: K.play.tr,
                                onPressed: () => Get.toNamed<void>(
                                  AppRoutes.audioPlayer,
                                  arguments: <String, Object>{
                                    'queue': <Map<String, String>>[
                                      <String, String>{
                                        'path': project.outputPath!,
                                        'title': project.fileName,
                                      },
                                    ],
                                    'index': 0,
                                  },
                                ),
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
