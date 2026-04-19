import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/core/providers/app_environment_provider.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/shared/presentation/widgets/app_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(currentIdentityProvider);
    final environment = ref.watch(appEnvironmentProvider);
    final firebaseBootstrap = ref.watch(firebaseBootstrapProvider);

    return AppScaffold(
      currentSection: AppSection.profile,
      title: 'Profile',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: <Widget>[
          OverviewCard(
            eyebrow: 'Identity',
            title: 'Device identity is stored locally and survives relaunches.',
            subtitle:
                'Remote code reservation and anonymous auth will layer on top '
                'of this state instead of replacing it.',
            children: <Widget>[
              identity.when(
                data: (value) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProfileField(
                        label: 'Short code',
                        value: value.shortCode.displayValue,
                      ),
                      _ProfileField(
                        label: 'Installation ID',
                        value: value.installationId,
                      ),
                      _ProfileField(
                        label: 'Created at',
                        value: value.createdAt.toIso8601String(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: value.shortCode.displayValue,
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Short code copied to clipboard.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy code'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              await ref
                                  .read(currentIdentityProvider.notifier)
                                  .refresh();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Identity refresh completed. If Firebase is configured, registration was retried.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh registration'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) {
                  return Text(
                    error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Firebase',
            title:
                'Runtime Firebase configuration is provided through dart-defines.',
            children: <Widget>[
              firebaseBootstrap.when(
                data: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProfileField(
                        label: 'Bootstrap status',
                        value: state.status.name,
                      ),
                      _ProfileField(
                        label: 'Bootstrap message',
                        value: state.message,
                      ),
                      _ProfileField(
                        label: 'Project ID',
                        value:
                            environment.firebase.projectId ?? 'Not configured',
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) {
                  return Text(
                    error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Runtime',
            title: 'Environment values that the transport layer must honor.',
            children: <Widget>[
              _ProfileField(
                label: 'Relay base URL',
                value: environment.relayBaseUrl,
              ),
              _ProfileField(
                label: 'Transfer TTL',
                value: '${environment.transferTtl.inHours} hours',
              ),
              _ProfileField(
                label: 'Max file size',
                value: ByteCountFormatter.format(environment.maxFileSizeBytes),
              ),
              _ProfileField(
                label: 'Metered warning threshold',
                value: ByteCountFormatter.format(
                  environment.meteredWarningThresholdBytes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
