import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'auth/sign_in_page.dart';
import 'l10n/app_localizations.dart';

/// Placeholder for the signed-in shell; Task 4 replaces it.
class HomePlaceholder extends ConsumerWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.info?.name ?? ''),
        actions: [
          TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: Text(l.signOut)),
        ],
      ),
      body: Center(child: Text(l.welcome('${s.user?['name'] ?? ''}'))),
    );
  }
}

String? sessionRedirect(SessionState s, String location) {
  final target = s.info == null ? '/splash' : (s.signedIn ? '/home' : '/sign-in');
  if (s.signedIn) {
    return (location == '/splash' || location == '/sign-in') ? '/home' : null;
  }
  return location == target ? null : target;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => sessionRedirect(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePlaceholder()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class WandApp extends ConsumerStatefulWidget {
  const WandApp({super.key});

  @override
  ConsumerState<WandApp> createState() => _WandAppState();
}

class _WandAppState extends ConsumerState<WandApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionProvider.notifier).start());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final loc = s.user?['locale'];
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (_) => s.info?.name ?? '',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: s.info?.seed ?? defaultAppColor),
      ),
      locale: loc is String && ['en', 'mn'].contains(loc) ? Locale(loc) : null,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
