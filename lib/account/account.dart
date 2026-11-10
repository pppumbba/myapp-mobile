import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../auth/session.dart';
import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import '../nav/shell.dart' show landingLocation, sectionTabProvider;
import '../nav/top_bar.dart' show AccountAvatar;
import '../widgets/error_banner.dart';
import '../widgets/glow_border.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/pull_refresh.dart' show RefreshRing;
import '../widgets/row_group.dart';
import '../widgets/snap_sheet.dart';
import '../widgets/tones.dart';
import '../widgets/skeleton.dart';
import '../widgets/drop_toast.dart';
import '../widgets/liquid_toggle.dart';

/// A language the customer has turned on (GET /languages).
typedef Language = ({String code, String name});

/// The active languages, loaded once per session scope.
final languagesProvider = FutureProvider<List<Language>>((ref) async {
  ref.watch(sessionScopeProvider);
  final r = await ref.read(apiClientProvider).get<dynamic>('/languages');
  final list = r is Map ? r['languages'] : null;
  return [
    if (list is List)
      for (final l in list)
        if (l is Map && l['is_active'] != false) (code: '${l['code']}', name: '${l['name'] ?? l['code']}'),
  ];
});

Map<String, dynamic>? _customerOf(Map<String, dynamic>? user) {
  final c = user?['customer'];
  return c is Map ? Map<String, dynamic>.from(c) : null;
}

List<Map<String, dynamic>> _customersOf(Map<String, dynamic>? user) {
  final list = user?['customers'];
  return [if (list is List) for (final c in list) if (c is Map) Map<String, dynamic>.from(c)];
}

/// The account sheet, as the web's user menu and profile page: who is signed in, their personal
/// info, password, light or dark, language and customers, and Sign out.
void showAccountSheet(BuildContext context) {
  showSnapSheet<void>(context, initial: SnapHeight.half, builder: (_) => const _AccountSheet());
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final name = '${user?['name'] ?? ''}';
    final email = '${user?['email'] ?? ''}';
    final locale = user?['locale'] as String?;
    final languages = ref.watch(languagesProvider).value;
    final languageName = locale == null ? l.languageAsPhone : (languages?.where((x) => x.code == locale).firstOrNull?.name ?? locale);
    final customer = _customerOf(user);

    // Laid out like the filter sheet: a title, then the rows; Sign out is a row of its own at the end.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.account, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    AccountAvatar(name: name, tooltip: l.account, onPressed: null, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (email.isNotEmpty)
                          Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  RowGroup(children: [
                    IconRow(icon: Icons.person_outline, title: l.personalInfo, onTap: () => _push(context, const PersonalInfoPage())),
                    IconRow(icon: Icons.lock_outline, title: l.password, onTap: () => _push(context, const PasswordPage())),
                    IconRow(icon: Icons.translate, title: l.language, value: languageName, onTap: () => _push(context, const LanguagePage())),
                    IconRow(icon: Icons.business_outlined, title: l.customers, value: customer?['name'] as String?, onTap: () => _push(context, const CustomersPage())),
                    IconRow(icon: Icons.contrast, title: l.appearance, trailing: const _ThemeModePicker()),
                  ]),
                  const SizedBox(height: 12),
                  RowGroup(children: [
                    IconRow(
                      icon: Icons.logout,
                      title: l.signOut,
                      color: scheme.error,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(sessionProvider.notifier).signOut();
                      },
                    ),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// System / Light / Dark as a liquid toggle: the violet → cyan drop flows to the picked one.
/// Saved at once.
class _ThemeModePicker extends ConsumerWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(sessionProvider.select((s) => s.user?['theme_mode'] as String?));
    final options = <(String?, String, IconData)>[
      (null, l.themeSystem, Icons.brightness_auto_outlined),
      ('light', l.themeLight, Icons.light_mode_outlined),
      ('dark', l.themeDark, Icons.dark_mode_outlined),
    ];
    Future<void> pick(String? m) async {
      try {
        await ref.read(sessionProvider.notifier).setThemeMode(m);
      } catch (e) {
        if (context.mounted) showDropToast(context, title: e is ApiError ? e.message : l.somethingWrong, icon: Icons.error_outline_rounded);
        rethrow; // the drop flows back
      }
    }

    return LiquidToggle<String?>(
      value: mode,
      onChanged: pick,
      options: [for (final (value, label, icon) in options) LiquidOption(value, icon, label)],
    );
  }
}

/// A pushed account page: a note under the title, the content, and the main button at the foot.
class _AccountPage extends StatelessWidget {
  final String title;
  final String note;
  final String? error;
  final List<Widget> children;
  final Widget? button;
  const _AccountPage({required this.title, required this.note, this.error, required this.children, this.button});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (error != null) ErrorBanner(message: error!),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
            Text(note, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            ...children,
          ]),
        ),
        if (button != null) SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: button)),
      ]),
    );
  }
}

/// A text box in the form fields' glowing outline.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? error;
  final String? helper;
  final bool obscure;
  final TextInputType? keyboard;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  const _Field({required this.controller, required this.label, this.error, this.helper, this.obscure = false, this.keyboard, this.autofill, this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          autofillHints: autofill,
          onChanged: onChanged,
          decoration: withGlowBorders(InputDecoration(labelText: label, errorText: error, helperText: helper, errorMaxLines: 3), Theme.of(context).colorScheme),
        ),
      );
}

/// Runs a save: field errors and a general error from the API, the Saved note and back on success.
mixin _Saving<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? error;
  Map<String, List<String>> fieldErrors = const {};

  String? fe(String field) => fieldErrors[field]?.firstOrNull;

  Future<void> save(Future<void> Function() run, String done) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      busy = true;
      error = null;
      fieldErrors = const {};
    });
    try {
      await run();
      if (mounted) showDropToast(context, title: done, icon: Icons.check_rounded);
      navigator.pop();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          fieldErrors = e.errors;
          if (e.errors.isEmpty) error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = l.somethingWrong;
        });
      }
    }
  }
}

Widget _buttonLabel(bool busy, String text) => busy ? const RefreshRing(size: 22, onGradient: true) : Text(text);

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> with _Saving {
  late final Map<String, dynamic>? _user = ref.read(sessionProvider).user;
  late final _name = TextEditingController(text: '${_user?['name'] ?? ''}');
  late final _email = TextEditingController(text: '${_user?['email'] ?? ''}');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final changed = _name.text.trim() != '${_user?['name'] ?? ''}' || _email.text.trim() != '${_user?['email'] ?? ''}';
    return _AccountPage(
      title: l.personalInfo,
      note: l.personalInfoNote,
      error: error,
      button: GradientButton(
        onPressed: busy || !changed || _name.text.trim().isEmpty || _email.text.trim().isEmpty
            ? null
            : () => save(() => ref.read(sessionProvider.notifier).updateProfile(_name.text.trim(), _email.text.trim()), l.saved),
        child: _buttonLabel(busy, l.saveChanges),
      ),
      children: [
        _Field(controller: _name, label: '${l.name} *', error: fe('name'), autofill: const [AutofillHints.name], onChanged: (_) => setState(() {})),
        _Field(
          controller: _email,
          label: '${l.email} *',
          error: fe('email'),
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> with _Saving {
  final _current = TextEditingController(), _next = TextEditingController(), _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mismatch = _confirm.text.isNotEmpty && _next.text != _confirm.text;
    final ready = _current.text.isNotEmpty && _next.text.isNotEmpty && _confirm.text.isNotEmpty && !mismatch;
    void changed(String _) => setState(() {});
    return _AccountPage(
      title: l.password,
      note: l.passwordNote,
      error: error,
      button: GradientButton(
        onPressed: busy || !ready
            ? null
            : () => save(() => ref.read(sessionProvider.notifier).changePassword(_current.text, _next.text, _confirm.text), l.passwordChanged),
        child: _buttonLabel(busy, l.changePassword),
      ),
      children: [
        _Field(controller: _current, label: l.currentPassword, error: fe('current_password'), obscure: true, autofill: const [AutofillHints.password], onChanged: changed),
        _Field(controller: _next, label: l.newPassword, error: fe('password'), helper: l.passwordHint, obscure: true, autofill: const [AutofillHints.newPassword], onChanged: changed),
        _Field(controller: _confirm, label: l.confirmPassword, error: mismatch ? l.passwordsDontMatch : null, obscure: true, autofill: const [AutofillHints.newPassword], onChanged: changed),
      ],
    );
  }
}

/// A row with a check on the right when it is the picked one, or a ring while it is being saved.
class _PickRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final bool picked;
  final bool busy;
  final VoidCallback? onTap;
  const _PickRow({required this.title, this.subtitle, this.badge, required this.picked, this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: picked,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
                ]),
              ),
              if (badge != null) ...[badge!, const SizedBox(width: 10)],
              SizedBox.square(
                dimension: 24,
                child: busy
                    ? const RefreshRing(size: 22)
                    : picked
                        ? const Icon(Icons.check_circle, color: pillCyan)
                        : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  /// The language being saved ('' for "as my phone is").
  String? _saving;
  String? _error;

  Future<void> _pick(String? code) async {
    if (_saving != null) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _saving = code ?? '';
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).setLocale(code);
    } on ApiError catch (e) {
      _error = e.message;
    } catch (_) {
      _error = l.somethingWrong;
    }
    if (mounted) setState(() => _saving = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(sessionProvider.select((s) => s.user?['locale'] as String?));
    final languages = ref.watch(languagesProvider);
    return _AccountPage(
      title: l.language,
      note: l.languageNote,
      error: _error ?? (languages.hasError ? l.somethingWrong : null),
      children: [
        switch (languages) {
          AsyncValue(:final value?) => RowGroup(indent: 16, children: [
              _PickRow(title: l.languageAsPhone, picked: locale == null, busy: _saving == '', onTap: () => _pick(null)),
              for (final lang in value)
                _PickRow(title: lang.name, picked: locale == lang.code, busy: _saving == lang.code, onTap: () => _pick(lang.code)),
            ]),
          AsyncValue(hasError: true) => Center(
              child: SoftButton(onPressed: () => ref.invalidate(languagesProvider), child: Text(l.retry)),
            ),
          _ => const Shimmer(child: RowGroupSkeleton(rows: 3, icons: false)),
        },
      ],
    );
  }
}

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  int? _opening;
  String? _error;

  /// Opens another customer, then starts over on the first tab of the app there.
  Future<void> _open(int id) async {
    if (_opening != null) return;
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);
    setState(() {
      _opening = id;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).switchCustomer(id);
      ref.invalidate(sectionTabProvider);
      navigator.popUntil((r) => r.isFirst);
      router.go(landingLocation);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = l.somethingWrong);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final current = _customerOf(user)?['id'];
    final customers = _customersOf(user);
    return _AccountPage(
      title: l.customers,
      note: l.customersNote,
      error: _error,
      children: [
        RowGroup(indent: 16, children: [
          for (final c in customers)
            _PickRow(
              title: '${c['name'] ?? ''}',
              subtitle: c['id'] == current ? l.openNow : null,
              badge: c['is_admin'] == true ? _Badge(l.admin) : null,
              picked: c['id'] == current,
              busy: _opening == c['id'],
              onTap: c['id'] == current || c['id'] is! num ? null : () => _open((c['id'] as num).toInt()),
            ),
        ]),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: ShapeDecoration(color: pillViolet.withValues(alpha: 0.18), shape: const StadiumBorder()),
        child: Text(text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.isDark ? const Color(0xFFB6A8FF) : pillViolet,
            )),
      );
}
