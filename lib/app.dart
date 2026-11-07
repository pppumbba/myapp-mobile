import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'auth/sign_in_page.dart';
import 'l10n/app_localizations.dart';
import 'nav/shell.dart';


String? sessionRedirect(SessionState s, String location) {
  final target = s.info == null ? '/splash' : (s.signedIn ? landingLocation : '/sign-in');
  if (s.signedIn) {
    return (location == '/splash' || location == '/sign-in') ? landingLocation : null;
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell, routeState: state),
        branches: [
          for (var i = 0; i < maxTabBranches; i++)
            StatefulShellBranch(routes: [GoRoute(path: '/t/$i', builder: (_, _) => TabRoot(i))]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: moreLocation,
              builder: (_, _) => const MorePage(),
              routes: [
                GoRoute(
                  path: 'screen/:id',
                  builder: (_, state) => MoreScreenPage(int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
        ],
      ),
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
