import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import 'confirm_dialog.dart' show PopInRoute;
import 'pill_buttons.dart';

// The Violet Datepicker's night colours.
const _stage = Color(0xFF13131C), _row = Color(0xFF1C1B2B), _hover = Color(0xFF26253A);
const _ink = Color(0xFFF4F4F8), _ink2 = Color(0xFFC4C2E0), _mute = Color(0xFF77758F), _mute2 = Color(0xFF6D6B88);
const _ring = Color(0xFF38C6FF), _ice = Color(0xFF9FE3FF), _glow = Color(0x8C6E5BFF);
const _gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pillViolet, pillCyan]);

/// Presses spring back past full size.
const _spring = Cubic(0.34, 1.56, 0.64, 1);

/// Asks for a day between [first] and [last], starting on [initial] (today when null).
/// Resolves to the day at midnight, or null when cancelled.
Future<DateTime?> showVioletDatePicker(
  BuildContext context, {
  DateTime? initial,
  required DateTime first,
  required DateTime last,
}) =>
    Navigator.of(context, rootNavigator: true).push<DateTime>(PopInRoute<DateTime>(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      cardKey: const ValueKey('date-card'),
      builder: (_) => VioletDatePicker(initial: initial, first: first, last: last),
    ));

/// A Monday-first month: the month over its year with round arrows, the days (the picked one
/// violet → cyan, today ringed in cyan), the picked day spelled out, then Cancel and Apply.
/// Swipe the days sideways to change month; they slide in from that side.
class VioletDatePicker extends StatefulWidget {
  final DateTime? initial;
  final DateTime first, last;
  const VioletDatePicker({super.key, this.initial, required this.first, required this.last});

  @override
  State<VioletDatePicker> createState() => _VioletDatePickerState();
}

class _VioletDatePickerState extends State<VioletDatePicker> {
  late DateTime _picked, _month;
  int _dir = 1;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  DateTime get _first => DateUtils.dateOnly(widget.first);
  DateTime get _last => DateUtils.dateOnly(widget.last);

  @override
  void initState() {
    super.initState();
    _picked = _clamp(DateUtils.dateOnly(widget.initial ?? DateTime.now()));
    _month = DateTime(_picked.year, _picked.month);
  }

  DateTime _clamp(DateTime d) => d.isBefore(_first) ? _first : (d.isAfter(_last) ? _last : d);

  bool _canShow(DateTime month) =>
      !month.isBefore(DateTime(_first.year, _first.month)) && !month.isAfter(DateTime(_last.year, _last.month));

  void _show(DateTime month) {
    if (!_canShow(month) || month == _month) return;
    setState(() {
      _dir = month.isAfter(_month) ? 1 : -1;
      _month = month;
    });
  }

  void _shift(int months) => _show(DateTime(_month.year, _month.month + months));

  void _pick(DateTime day) {
    setState(() => _picked = day);
    _show(DateTime(day.year, day.month));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: _stage,
          elevation: 16,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Header(
                month: _month,
                locale: l.localeName,
                onPrev: _canShow(DateTime(_month.year, _month.month - 1)) ? () => _shift(-1) : null,
                onNext: _canShow(DateTime(_month.year, _month.month + 1)) ? () => _shift(1) : null,
              ),
              const SizedBox(height: 8),
              _Weekdays(locale: l.localeName),
              _days(context),
              const SizedBox(height: 8),
              _Summary(
                picked: _picked,
                today: _today,
                locale: l.localeName,
                onToday: _picked == _today || _today.isBefore(_first) || _today.isAfter(_last) ? null : () => _pick(_today),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: SoftButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel))),
                const SizedBox(width: 12),
                Expanded(child: GradientButton(onPressed: () => Navigator.of(context).pop(_picked), child: Text(l.apply))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _days(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 300) _shift(v < 0 ? 1 : -1);
      },
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 240),
          reverseDuration: Duration.zero,
          transitionBuilder: (child, animation) {
            final eased = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            return FadeTransition(
              opacity: eased,
              child: SlideTransition(
                position: Tween(begin: Offset(0.08 * _dir, 0), end: Offset.zero).animate(eased),
                child: child,
              ),
            );
          },
          child: _MonthDays(
            key: ValueKey(_month),
            month: _month,
            picked: _picked,
            today: _today,
            first: _first,
            last: _last,
            locale: AppLocalizations.of(context).localeName,
            onPick: _pick,
          ),
        ),
      ),
    );
  }
}

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Today", "Tomorrow", "In 3 days", "2 days ago".
String _fromToday(AppLocalizations l, DateTime day, DateTime today) {
  final days = DateUtils.dateOnly(day).difference(today).inHours / 24;
  final n = days.round();
  if (n == 0) return l.today;
  if (n == 1) return l.tomorrow;
  if (n == -1) return l.yesterday;
  return n > 0 ? l.inDays(n) : l.daysAgo(-n);
}

class _Header extends StatelessWidget {
  final DateTime month;
  final String locale;
  final VoidCallback? onPrev, onNext;
  const _Header({required this.month, required this.locale, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    final m = MaterialLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(color: _row, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_capitalized(DateFormat.MMMM(locale).format(month)),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink, height: 1.2)),
              Text(DateFormat.y(locale).format(month),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _mute, height: 1.2, fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
        _RoundButton(icon: Icons.chevron_left_rounded, tooltip: m.previousMonthTooltip, onPressed: onPrev),
        _RoundButton(icon: Icons.chevron_right_rounded, tooltip: m.nextMonthTooltip, onPressed: onNext),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _RoundButton({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      color: _ink2,
      disabledColor: _mute2.withValues(alpha: 0.5),
      highlightColor: _hover,
      style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
    );
    return onPressed == null ? button : _Springy(child: button);
  }
}

class _Weekdays extends StatelessWidget {
  final String locale;
  const _Weekdays({required this.locale});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat.E(locale);
    // 1 January 2024 was a Monday.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(f.format(DateTime(2024, 1, 1 + i)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _mute2, letterSpacing: 0.25)),
            ),
        ]),
      ),
    );
  }
}

/// Six weeks from the Monday on or before the 1st, so every month takes the same height.
class _MonthDays extends StatelessWidget {
  final DateTime month, picked, today, first, last;
  final String locale;
  final ValueChanged<DateTime> onPick;
  const _MonthDays({
    super.key,
    required this.month,
    required this.picked,
    required this.today,
    required this.first,
    required this.last,
    required this.locale,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final lead = month.weekday - DateTime.monday;
    final label = DateFormat.yMMMMEEEEd(locale);
    return Column(children: [
      for (var week = 0; week < 6; week++)
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final day = DateTime(month.year, month.month, 1 - lead + week * 7 + i);
                final enabled = !day.isBefore(first) && !day.isAfter(last);
                return _Day(
                  day: day,
                  label: label.format(day),
                  isPicked: day == picked,
                  isToday: day == today,
                  isOutside: day.month != month.month,
                  onTap: enabled ? () => onPick(day) : null,
                );
              }),
            ),
        ]),
    ]);
  }
}

class _Day extends StatelessWidget {
  final DateTime day;
  final String label;
  final bool isPicked, isToday, isOutside;
  final VoidCallback? onTap;
  const _Day({
    required this.day,
    required this.label,
    required this.isPicked,
    required this.isToday,
    required this.isOutside,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPicked ? Colors.white : (isToday ? _ink : (isOutside ? _mute2.withValues(alpha: 0.7) : _ink2));
    return Semantics(
      button: true,
      selected: isPicked,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: _Springy(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isPicked ? _gradient : null,
                  border: isToday && !isPicked ? Border.all(color: _ring, width: 2) : null,
                  boxShadow: isPicked ? const [BoxShadow(color: _glow, blurRadius: 14)] : null,
                ),
                child: Text('${day.day}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isPicked ? FontWeight.w800 : FontWeight.w500,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shrinks to 86% while held and springs back on release. With [onTap] it is the tap target
/// itself; without, it only watches the presses of the button inside.
class _Springy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Springy({required this.child, this.onTap});

  @override
  State<_Springy> createState() => _SpringyState();
}

class _SpringyState extends State<_Springy> {
  bool _down = false;

  void _hold(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scaled = AnimatedScale(
      scale: _down && !still ? 0.86 : 1,
      duration: const Duration(milliseconds: 350),
      curve: _spring,
      child: widget.child,
    );
    if (widget.onTap == null) {
      return Listener(onPointerDown: (_) => _hold(true), onPointerUp: (_) => _hold(false), onPointerCancel: (_) => _hold(false), child: scaled);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _hold(true),
      onTapUp: (_) => _hold(false),
      onTapCancel: () => _hold(false),
      onTap: widget.onTap,
      child: scaled,
    );
  }
}

/// The picked day in a violet → cyan circle, spelled out, how far it is from today, and Today.
class _Summary extends StatelessWidget {
  final DateTime picked, today;
  final String locale;
  final VoidCallback? onToday;
  const _Summary({required this.picked, required this.today, required this.locale, this.onToday});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(color: _row, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _gradient),
          child: ExcludeSemantics(
            child: Text('${picked.day}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_capitalized(DateFormat.MMMMEEEEd(locale).format(picked)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink2, height: 1.25)),
              Text('${picked.year} · ${_fromToday(l, picked, today)}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: _mute, height: 1.25)),
            ]),
          ),
        ),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            foregroundColor: _ice,
            disabledForegroundColor: _mute2,
            overlayColor: _hover,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: Text(l.today),
        ),
      ]),
    );
  }
}
