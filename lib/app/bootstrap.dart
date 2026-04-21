import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/app/app.dart';
import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';

class NeoSapienBootstrap extends ConsumerWidget {
  const NeoSapienBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(firebaseBootstrapProvider);

    return bootstrapState.when(
      data: (state) {
        if (state.status == FirebaseBootstrapStatus.ready) {
          return const NeoSapienApp();
        }
        final title = state.status == FirebaseBootstrapStatus.unconfigured
            ? 'Firebase not configured'
            : 'Firebase bootstrap failed';
        final details = state.error != null
            ? '${state.message}\n\nUnderlying error: ${state.error}'
            : state.message;
        return _BootstrapShell(
          title: title,
          message: details,
          isError: true,
        );
      },
      loading: () {
        return const _BootstrapShell(
          title: 'Bootstrapping',
          message: 'Initializing platform services and runtime configuration.',
        );
      },
      error: (error, stackTrace) {
        return _BootstrapShell(
          title: 'Bootstrap failed',
          message: error.toString(),
          isError: true,
        );
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({
    required this.title,
    required this.message,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF3F6FB),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.hourglass_top_rounded,
                          size: 32,
                          color: isError
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (!isError) ...<Widget>[
                          const SizedBox(height: 20),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
