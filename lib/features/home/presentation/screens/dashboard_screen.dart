import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neo_sapien/app/router/app_section.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/shared/presentation/widgets/app_scaffold.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(currentIdentityProvider);

    return AppScaffold(
      currentSection: AppSection.dashboard,
      title: 'NeoSapien',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: <Widget>[
          _IdentityHero(identity: identity),
          const SizedBox(height: 32),
          _QuickActions(),
        ],
      ),
    );
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.identity});

  final AsyncValue<UserIdentity> identity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: identity.when(
          data: (value) {
            final code = value.shortCode.displayValue;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your code',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  code,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share this code so friends can send you files.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy code'),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(
            error.toString(),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => context.go(AppSection.send.path),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Send files'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => context.go(AppSection.inbox.path),
          icon: const Icon(Icons.inbox_rounded),
          label: const Text('Open inbox'),
        ),
      ],
    );
  }
}
