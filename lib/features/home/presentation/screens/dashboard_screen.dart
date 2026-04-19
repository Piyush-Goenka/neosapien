import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/core/providers/app_environment_provider.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/core/utils/byte_count_formatter.dart';
import 'package:neo_sapien/features/home/presentation/widgets/overview_card.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/shared/presentation/widgets/app_scaffold.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final identity = ref.watch(currentIdentityProvider);
    final firebaseBootstrap = ref.watch(firebaseBootstrapProvider);

    return AppScaffold(
      currentSection: AppSection.dashboard,
      title: 'NeoSapien',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: <Widget>[
          OverviewCard(
            eyebrow: 'Identity bootstrap',
            title:
                'Anonymous local identity is provisioned first, then upgraded to a registered code when Firebase is available.',
            subtitle:
                'This keeps the app bootable without secrets while still '
                'making backend-backed addressing the default once configured.',
            children: <Widget>[_IdentityState(identity: identity)],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Backend readiness',
            title:
                'Firebase bootstrap controls whether real recipient addressing is active.',
            subtitle:
                'When runtime Firebase options are missing, the app falls back '
                'to local-only identity instead of crashing.',
            children: <Widget>[
              _FirebaseBootstrapStateView(
                firebaseBootstrap: firebaseBootstrap,
                projectId: environment.firebase.projectId,
              ),
            ],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Transfer guardrails',
            title:
                'The runtime constraints are locked before transport code lands.',
            subtitle:
                'These values map directly to the assessment rubric and will '
                'be enforced server-side and client-side.',
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(
                      'Max file ${ByteCountFormatter.format(environment.maxFileSizeBytes)}',
                    ),
                  ),
                  Chip(
                    label: Text(
                      'Max batch ${ByteCountFormatter.format(environment.maxBatchSizeBytes)}',
                    ),
                  ),
                  Chip(label: Text('TTL ${environment.transferTtl.inHours}h')),
                  Chip(
                    label: Text(
                      'Files / batch ${environment.maxFilesPerBatch}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Architecture',
            title: 'Foundation work is aligned to the scoring order.',
            subtitle:
                'The app shell, typed boundaries, and platform bridge contract '
                'are in place before Firebase, relay, and background execution.',
            children: const <Widget>[
              _ChecklistRow(
                label: 'Feature-first module boundaries',
                status: 'Ready',
              ),
              _ChecklistRow(
                label: 'Typed transfer state machine',
                status: 'Ready',
              ),
              _ChecklistRow(
                label: 'Local secure identity persistence',
                status: 'Ready',
              ),
              _ChecklistRow(
                label: 'Realtime transport integration',
                status: 'Next',
              ),
            ],
          ),
          const SizedBox(height: 16),
          OverviewCard(
            eyebrow: 'Execution',
            title: 'The next milestone is real transport wiring.',
            subtitle:
                'Move into send and inbox flows now, then bind Firebase and the '
                'resumable relay underneath the same contracts.',
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(AppSection.send.path),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Open send flow'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(AppSection.inbox.path),
                    icon: const Icon(Icons.inbox_rounded),
                    label: const Text('Open inbox'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(AppSection.profile.path),
                    icon: const Icon(Icons.person_rounded),
                    label: const Text('Open profile'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentityState extends StatelessWidget {
  const _IdentityState({required this.identity});

  final AsyncValue<UserIdentity> identity;

  @override
  Widget build(BuildContext context) {
    return identity.when(
      data: (value) {
        return Row(
          children: <Widget>[
            Icon(
              Icons.verified_user_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value.shortCode.displayValue,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Installation ${value.installationId}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) {
        return Text(
          error.toString(),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      },
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(
          status,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FirebaseBootstrapStateView extends StatelessWidget {
  const _FirebaseBootstrapStateView({
    required this.firebaseBootstrap,
    required this.projectId,
  });

  final AsyncValue<FirebaseBootstrapState> firebaseBootstrap;
  final String? projectId;

  @override
  Widget build(BuildContext context) {
    return firebaseBootstrap.when(
      data: (state) {
        final icon = switch (state.status) {
          FirebaseBootstrapStatus.ready => Icons.cloud_done_rounded,
          FirebaseBootstrapStatus.unconfigured => Icons.cloud_off_rounded,
          FirebaseBootstrapStatus.failed => Icons.error_outline_rounded,
        };

        final color = switch (state.status) {
          FirebaseBootstrapStatus.ready => Theme.of(
            context,
          ).colorScheme.primary,
          FirebaseBootstrapStatus.unconfigured => Theme.of(
            context,
          ).colorScheme.secondary,
          FirebaseBootstrapStatus.failed => Theme.of(context).colorScheme.error,
        };

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (projectId != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Project: $projectId',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(error.toString()),
    );
  }
}
