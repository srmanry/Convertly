import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/legal/privacy_policy.dart';

/// The privacy policy, readable without a connection.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
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
                  'Effective ${PrivacyPolicy.effectiveDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                SelectableText(
                  PrivacyPolicy.intro,
                  style: theme.textTheme.bodyMedium,
                ),
                for (final PolicySection section in PrivacyPolicy.sections)
                  _Section(section: section),
                if (PrivacyPolicy.contactEmail.isNotEmpty)
                  _Section(
                    section: PolicySection(
                      title: 'Contact',
                      paragraphs: <String>[
                        'Questions about this policy: '
                            '${PrivacyPolicy.contactEmail}',
                      ],
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
        ],
      ),
    );
  }
}
