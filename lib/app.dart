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
import 'widgets/tones.dart' show appFont;


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
    final seed = s.info?.seed ?? defaultAppColor;
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (_) => s.info?.name ?? '',
      theme: appTheme(seed, brightness: Brightness.light),
      darkTheme: appTheme(seed),
      // The user's pick (web profile or the account sheet); none follows the phone.
      themeMode: switch (s.user?['theme_mode']) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
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
/// Light: the same layout on a pale grey page with white cards, the violet and cyan kept.
ThemeData appTheme(Color seed, {Brightness brightness = Brightness.dark}) {
  final dark = brightness == Brightness.dark;
  final page = dark ? const Color(0xFF13131C) : const Color(0xFFF4F4F9);
  final card = dark ? const Color(0xFF1B1A28) : Colors.white;
  final label = dark ? const Color(0xFF9D9BBB) : const Color(0xFF6B6985);
  final helper = dark ? const Color(0xFF77758F) : const Color(0xFF85839C);
  // Cyan is too pale for text on white: a deeper blue there.
  final accent = dark ? pillCyan : const Color(0xFF0B86C8);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
    surface: page,
    surfaceContainerLowest: dark ? const Color(0xFF0E0E15) : Colors.white,
    surfaceContainerLow: card,
    surfaceContainer: dark ? const Color(0xFF1F1E2E) : const Color(0xFFEDEDF4),
    surfaceContainerHigh: dark ? const Color(0xFF24223A) : Colors.white,
    surfaceContainerHighest: dark ? const Color(0xFF2C2A42) : const Color(0xFFE4E3EE),
    onSurface: dark ? const Color(0xFFF4F4F8) : const Color(0xFF17161F),
    onSurfaceVariant: dark ? const Color(0xFFA9A7C4) : const Color(0xFF63617C),
    outlineVariant: dark ? const Color(0x14FFFFFF) : const Color(0x1A000000),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: appFont,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    // Pages slide in from the right and are dragged back from their left edge.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: SwipeBackTransitionsBuilder(),
      TargetPlatform.iOS: SwipeBackTransitionsBuilder(),
    }),
    // Page names sit in the middle on every platform (Android puts them left by default).
    appBarTheme: AppBarTheme(backgroundColor: page, surfaceTintColor: Colors.transparent, centerTitle: true),
    // Field labels turn cyan on focus (the glowing outline itself is set on form fields: fieldBorders).
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: label, fontWeight: FontWeight.w600),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                    ? accent
                    : label,
          )),
      helperStyle: TextStyle(color: helper, fontWeight: FontWeight.w500),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: accent, selectionColor: accent.withValues(alpha: 0.3), selectionHandleColor: accent),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0x0FFFFFFF) : const Color(0x14000000)),
      ),
    ),
  );
}
