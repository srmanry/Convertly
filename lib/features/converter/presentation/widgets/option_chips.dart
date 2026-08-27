import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';

/// A labelled row of single-choice chips.
class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    super.key,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppDimens.spaceMd),
        Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: <Widget>[
            for (final T option in options)
              ChoiceChip(
                label: Text(labelBuilder(option)),
                selected: option == selected,
                onSelected: (bool isSelected) {
                  if (isSelected) {
                    onSelected(option);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
