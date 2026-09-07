import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_depth.dart';
import '../../../../core/widgets/search_field_border.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/entities/song.dart';
import '../controllers/music_library_controller.dart';

/// Plays what is already on the phone, and what the app has made.
class MusicLibraryPage extends GetView<MusicLibraryController> {
  const MusicLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Column(
              children: <Widget>[
                _SourceTabs(controller: controller),
                _SearchField(controller: controller),
                Expanded(child: _SongList(controller: controller)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone music or the app's own files.
class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.controller});

  final MusicLibraryController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.pagePadding,
          vertical: AppDimens.spaceSm,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(
              alpha: isDark ? 0.72 : 0.82,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.48 : 0.62,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceXs),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _SourceTabButton(
                      label: 'Phone',
                      icon: Icons.smartphone_rounded,
                      selected: controller.tab.value == SongTab.phone,
                      onTap: () => controller.setTab(SongTab.phone),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  Expanded(
                    child: _SourceTabButton(
                      label: 'In app',
                      icon: Icons.library_music_rounded,
                      selected: controller.tab.value == SongTab.app,
                      onTap: () => controller.setTab(SongTab.app),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTabButton extends StatelessWidget {
  const _SourceTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = selected
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          gradient: selected
              ? AppDepth.dome(colors.primary, isDark: isDark)
              : null,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: selected ? AppDepth.rim(isDark) : Colors.transparent,
          ),
          boxShadow: selected
              ? AppDepth.lift(
                  isDark: isDark,
                  elevation: 0.45,
                  tint: colors.primary,
                )
              : const <BoxShadow>[],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      icon,
                      key: ValueKey<bool>(selected),
                      size: AppDimens.iconSm,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final MusicLibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: TextField(
        onChanged: controller.setQuery,
        decoration: InputDecoration(
          hintText: 'Search',
          suffixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          border: searchFieldBorder(),
          enabledBorder: searchFieldBorder(),
          focusedBorder: searchFieldBorder(
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({required this.controller});

  final MusicLibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.visibleSongs.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // Being refused is a normal answer, not an error: the screen explains
      // what the permission is for and lets the user decide again.
      if (controller.tab.value == SongTab.phone &&
          !controller.hasDeviceAccess.value) {
        return EmptyStateView(
          icon: Icons.lock_outline_rounded,
          title: 'Let the app see your music',
          message:
              'To list the songs already on this phone, the app needs '
              'permission to read audio files. Nothing else is read, and '
              'nothing leaves the device.',
          action: FilledButton.icon(
            onPressed: controller.grantDeviceAccess,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Allow'),
          ),
        );
      }

      final List<Song> songs = controller.visibleSongs;
      if (songs.isEmpty) {
        return EmptyStateView(
          icon: Icons.music_off_rounded,
          title: controller.query.value.isNotEmpty
              ? 'Nothing matches that'
              : 'No music here yet',
          message: controller.query.value.isNotEmpty
              ? 'Try a different word.'
              : controller.tab.value == SongTab.phone
              ? 'No songs were found on this phone.'
              : 'Files you convert will show up here.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.spaceMd,
            AppDimens.pagePadding,
            AppDimens.spaceXxl,
          ),
          itemCount: songs.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
          itemBuilder: (BuildContext context, int index) =>
              _SongRow(song: songs[index], controller: controller),
        ),
      );
    });
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.controller});

  final Song song;
  final MusicLibraryController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String details = <String>[
      if (song.subtitle case final String artist) artist,
      if (song.duration case final Duration duration)
        Formatters.duration(duration),
      if (song.sizeInBytes case final int size) Formatters.fileSize(size),
    ].join('  ·  ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            song.source == SongSource.phone
                ? Icons.music_note_rounded
                : Icons.library_music_rounded,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: const Icon(Icons.play_arrow_rounded),
        onTap: () => controller.play(song),
      ),
    );
  }
}
