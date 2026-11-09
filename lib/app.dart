import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'auth/sign_in_page.dart';
import 'l10n/app_localizations.dart';
import 'nav/pill_bar.dart' show pillCyan;
import 'nav/shell.dart';
import 'widgets/swipe_back.dart';


/// Signed in: off the splash and sign-in pages. Otherwise the splash while the app info loads or a
/// saved token is restored (its error shows Retry there), and sign-in only once there is no token.
String? sessionRedirect(SessionState s, String location) {
  if (s.signedIn) {
    return (location == '/splash' || location == '/sign-in') ? landingLocation : null;
  }
  final target = s.info == null || s.restoring ? '/splash' : '/sign-in';
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
      theme: appTheme(s.info?.seed ?? defaultAppColor),
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

/// Dark, in the bottom menu's colours: the page a shade deeper than the menu, cards in the menu's own tone.
ThemeData appTheme(Color seed) {
  const page = Color(0xFF13131C), card = Color(0xFF1B1A28);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
    surface: page,
    surfaceContainerLowest: const Color(0xFF0E0E15),
    surfaceContainerLow: card,
    surfaceContainer: const Color(0xFF1F1E2E),
    surfaceContainerHigh: const Color(0xFF24223A),
    surfaceContainerHighest: const Color(0xFF2C2A42),
    onSurface: const Color(0xFFF4F4F8),
    onSurfaceVariant: const Color(0xFFA9A7C4),
    outlineVariant: const Color(0x14FFFFFF),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    // Pages slide in from the right and are dragged back from their left edge.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: SwipeBackTransitionsBuilder(),
      TargetPlatform.iOS: SwipeBackTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(backgroundColor: page, surfaceTintColor: Colors.transparent),
    // Field labels turn cyan on focus (the glowing outline itself is set on form fields: fieldBorders).
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: Color(0xFF9D9BBB), fontWeight: FontWeight.w600),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                    ? pillCyan
                    : const Color(0xFF9D9BBB),
          )),
      helperStyle: const TextStyle(color: Color(0xFF77758F), fontWeight: FontWeight.w500),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: pillCyan, selectionColor: pillCyan.withValues(alpha: 0.3), selectionHandleColor: pillCyan),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x0FFFFFFF))),
    ),
  );
}
