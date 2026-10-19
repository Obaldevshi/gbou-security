import 'package:flutter/material.dart';
import 'package:mobile_template/app/theme/app_dimensions.dart';
import 'package:mobile_template/core/extensions/build_context_extensions.dart';
import 'package:mobile_template/features/privacy/domain/privacy_policy.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({required this.repository, super.key});
  final PrivacyPolicyRepository repository;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late var _future = widget.repository.load();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.privacyTitle)),
    body: SafeArea(
      child: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data!.fold(
            (failure) => Center(
              child: Padding(
                padding: AppDimensions.paddingAllL,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(failure.message),
                    TextButton(
                      onPressed: () =>
                          setState(() => _future = widget.repository.load()),
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
            (policy) => SingleChildScrollView(
              padding: AppDimensions.paddingAllL,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          policy.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(policy.version),
                        const SizedBox(height: 16),
                        if (!policy.ready)
                          Card(
                            child: Padding(
                              padding: AppDimensions.paddingAllM,
                              child: Text(context.l10n.privacyDraft),
                            ),
                          ),
                        if (policy.operatorName.isNotEmpty)
                          Text(policy.operatorName),
                        if (policy.contactEmail.isNotEmpty)
                          Text(policy.contactEmail),
                        if (policy.retentionPolicy.isNotEmpty)
                          Text(policy.retentionPolicy),
                        for (final section in policy.sections) ...[
                          const SizedBox(height: 20),
                          Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(section.text),
                        ],
                        const SizedBox(height: 24),
                        SelectableText(policy.publicUrl),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
