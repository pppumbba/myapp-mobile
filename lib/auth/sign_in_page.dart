import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import '../widgets/wand_mark.dart';
import 'session.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: s.error != null && !s.loading
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.read(sessionProvider.notifier).start(),
                      child: Text(l.retry),
                    ),
                    if (s.restoring) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.read(sessionProvider.notifier).abandonRestore(),
                        child: Text(l.signOut),
                      ),
                    ],
                  ],
                ),
              )
            : const Column(mainAxisSize: MainAxisSize.min, children: [
                WandMark(size: 64),
                SizedBox(height: 28),
                SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
              ]),
      ),
    );
  }
}

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    ref.read(sessionProvider.notifier).signIn(_email.text.trim(), _password.text);
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: border(const Color(0x14FFFFFF)),
      enabledBorder: border(const Color(0x14FFFFFF)),
      focusedBorder: border(pillViolet, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final google = ref.watch(googleSignInProvider).value ?? false;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: pillViolet.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: 2)],
                          ),
                          child: const WandMark(size: 72),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(l.welcomeBack, textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(l.signInToContinue, textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: _field(l.email, Icons.mail_outline),
                        validator: required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _field(
                          l.password,
                          Icons.lock_outline,
                          suffix: IconButton(
                            tooltip: _showPassword ? l.hidePassword : l.showPassword,
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: required,
                      ),
                      if (s.error != null) ...[
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.error_outline, size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.error!, style: TextStyle(color: scheme.error))),
                        ]),
                      ],
                      const SizedBox(height: 24),
                      _GradientButton(
                        onPressed: s.loading ? null : _submit,
                        child: s.loading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : Text(l.signIn),
                      ),
                      if (google) ...[
                        const SizedBox(height: 24),
                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(l.or, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: s.loading ? null : () => ref.read(sessionProvider.notifier).signInWithGoogle(),
                            icon: const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleG())),
                            label: Text(l.continueWithGoogle),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onSurface,
                              backgroundColor: scheme.surfaceContainerHigh,
                              side: const BorderSide(color: Color(0x1FFFFFFF)),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// The brand's violet-to-cyan pill button.
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return Opacity(
      opacity: on ? 1 : 0.7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: const LinearGradient(colors: [pillViolet, pillCyan]),
          boxShadow: [if (on) BoxShadow(color: pillViolet.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 54,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour G, drawn as arcs so no image is needed.
class _GoogleG extends CustomPainter {
  const _GoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    Paint p(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const deg = 3.14159265 / 180;
    canvas.drawArc(r, -40 * deg, -100 * deg, false, p(0xFFEA4335)); // red, top
    canvas.drawArc(r, -140 * deg, -90 * deg, false, p(0xFFFBBC05)); // yellow, left
    canvas.drawArc(r, -230 * deg, -95 * deg, false, p(0xFF34A853)); // green, bottom
    canvas.drawArc(r, 35 * deg, -35 * deg, false, p(0xFF4285F4)); // blue, right
    // The G's bar.
    canvas.drawRect(Rect.fromLTWH(size.width / 2, size.height / 2 - w / 2, size.width / 2 - w * 0.1, w), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(_GoogleG oldDelegate) => false;
}
