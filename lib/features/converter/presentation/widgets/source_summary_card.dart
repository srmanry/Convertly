import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_info.dart';

/// Shows the selected file's name, size, duration and format.
class SourceSummaryCard extends StatelessWidget {
  const SourceSummaryCard({
    required this.media,
    super.key,
    this.onRemove,
    this.leading,
  });

  final MediaInfo media;
  final VoidCallback? onRemove;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Row(
          children: <Widget>[
            leading ??
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Icon(
                    media.hasVideo
                        ? Icons.movie_rounded
                        : Icons.audiotrack_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
            const SizedBox(width: AppDimens.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    media.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    <String>[
                      Formatters.fileSize(media.sizeInBytes),
                      if (media.duration case final Duration duration)
                        Formatters.duration(duration),
                      if (media.extension.isNotEmpty)
                        media.extension.toUpperCase(),
                    ].join('  ·  '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
