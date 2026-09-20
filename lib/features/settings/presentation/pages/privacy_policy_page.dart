import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/legal/privacy_policy.dart';
import '../../../../core/i18n/translation_keys.dart';

/// The privacy policy, readable without a connection.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(K.privacyPolicy.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              children: <Widget>[
                Text(
                  'Last Updated: ${PrivacyPolicy.lastUpdatedDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                for (final String paragraph
                    in PrivacyPolicy.introParagraphs) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceMd),
                  SelectableText(paragraph, style: theme.textTheme.bodyMedium),
                ],
                for (final PolicySection section in PrivacyPolicy.sections)
                  _Section(section: section),
                const SizedBox(height: AppDimens.spaceXl),
                Center(
                  child: SelectableText(
                    '${PrivacyPolicy.appName}\n'
                    '${PrivacyPolicy.footerTagline}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final PolicySection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            section.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final String paragraph in section.paragraphs) ...<Widget>[
            const SizedBox(height: AppDimens.spaceSm),
            SelectableText(paragraph, style: theme.textTheme.bodyMedium),
          ],
          for (final String bullet in section.bullets) ...<Widget>[
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText('• ', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: SelectableText(
                    bullet,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
