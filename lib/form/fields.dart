import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../grid/cells.dart';
import '../l10n/app_localizations.dart';
import 'lookup.dart';
import 'lookup_page.dart';
import 'values.dart';
import '../widgets/glow_border.dart';
import '../widgets/liquid_switch.dart';
import '../widgets/snap_sheet.dart';
import '../widgets/violet_date_picker.dart';

enum _Kind { boolean, lookup, select, date, datetime, textarea, number, text, other }

/// The web `Field` switch: which control a param gets.
_Kind _kindOf(MetaParam p) {
  if (p.dataType == 'boolean') return _Kind.boolean;
  if (isLookup(p)) return _Kind.lookup;
  if (optionsOf(p) != null) return _Kind.select;
  if (p.dataType == 'date') return _Kind.date;
  if (p.dataType == 'datetime') return _Kind.datetime;
  if (p.renderType == 'textarea' || p.dataType == 'text') return _Kind.textarea;
  if (p.dataType == 'integer' || p.dataType == 'decimal') return _Kind.number;
  if (p.dataType == null || p.dataType == '' || p.dataType == 'string') return _Kind.text;
  return _Kind.other;
}

/// One form field, full width. Values are Strings, or a bool for boolean fields.
/// [optional] drops the required mark (e.g. an autonumber); [hint] shows under the field.
class FieldInput extends ConsumerStatefulWidget {
  final MetaParam p;
  final Object? value;
  final ValueChanged<Object> onChanged;
  final String? error;
  final bool readOnly;
  final String? hint;
  final bool optional;

  const FieldInput({
    super.key,
    required this.p,
    required this.value,
    required this.onChanged,
    this.error,
    this.readOnly = false,
    this.hint,
    this.optional = false,
  });

  @override
  ConsumerState<FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends ConsumerState<FieldInput> {
  TextEditingController? _text;
  // The lookup label of the value it was resolved for.
  (String, String?)? _lookup;

  _Kind get _kind => _kindOf(widget.p);
  String get _str => widget.value == null || widget.value is bool ? '' : '${widget.value}';

  @override
  void initState() {
    super.initState();
    if (_isTyped) _text = TextEditingController(text: _str);
    _resolveLookup();
  }

  bool get _isTyped => _kind == _Kind.text || _kind == _Kind.textarea || _kind == _Kind.number;

  @override
  void didUpdateWidget(FieldInput old) {
    super.didUpdateWidget(old);
    if (_isTyped) {
      _text ??= TextEditingController();
      if (_text!.text != _str) _text!.text = _str;
    }
    if (old.value != widget.value || old.p != widget.p) _resolveLookup();
  }

  @override
  void dispose() {
    _text?.dispose();
    super.dispose();
  }

  void _resolveLookup() {
    if (_kind != _Kind.lookup) return;
    final spec = lookupSpecOf(widget.p);
    final v = _str;
    if (spec == null || v.isEmpty || _lookup?.$1 == v) return;
    final svc = ref.read(lookupServiceProvider);
    final cached = svc.cachedText(spec, v);
    if (cached != null) {
      _lookup = (v, cached);
      return;
    }
    _lookup = null;
    svc.lookupText(spec, v).then((t) {
      if (mounted && _str == v) setState(() => _lookup = (v, t ?? '#$v'));
    }, onError: (_) {
      if (mounted && _str == v) setState(() => _lookup = (v, '#$v'));
    });
  }

  String get _label {
    final required = widget.p.isRequired && !widget.optional && widget.p.dataType != 'boolean';
    return required ? '${widget.p.label} *' : widget.p.label;
  }

  InputDecoration _decoration(AppLocalizations l, {Widget? suffix}) => withGlowBorders(InputDecoration(
        labelText: _label,
        errorText: widget.error,
        helperText: widget.hint,
        helperMaxLines: 3,
        errorMaxLines: 3,
        filled: widget.readOnly,
        suffixIcon: suffix,
      ), Theme.of(context).colorScheme);

  String _display(AppLocalizations l) {
    final v = _str;
    if (v.isEmpty) return '';
    switch (_kind) {
      case _Kind.select:
        return optionsOf(widget.p)!.where((o) => o.id == v).firstOrNull?.label ?? v;
      case _Kind.datetime:
        return v.replaceFirst('T', ' ');
      case _Kind.lookup:
        return _lookup?.$1 == v ? (_lookup!.$2 ?? '#$v') : '…';
      default:
        return v;
    }
  }

  Future<void> _pick(BuildContext context) async {
    switch (_kind) {
      case _Kind.lookup:
        final spec = lookupSpecOf(widget.p)!;
        final row = await pickLookup(context, spec);
        if (row == null || !mounted) return;
        final v = row[spec.valueField];
        if (v == null) return;
        setState(() => _lookup = ('$v', rowLabel(row, spec.displayField)));
        widget.onChanged('$v');
      case _Kind.select:
        final picked = await showSnapSheet<String>(
          context,
          initial: SnapHeight.peek,
          builder: (ctx) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              for (final o in optionsOf(widget.p)!)
                ListTile(
                  title: Text(o.label),
                  trailing: o.id == _str ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(ctx).pop(o.id),
                ),
            ]),
          ),
        );
        if (picked != null) widget.onChanged(picked);
      case _Kind.date:
      case _Kind.datetime:
        final current = DateTime.tryParse(_str);
        final day = await showVioletDatePicker(
          context,
          initial: current,
          first: DateTime(1900),
          last: DateTime(2100),
        );
        if (day == null || !context.mounted) return;
        if (_kind == _Kind.date) {
          widget.onChanged(ymd(day));
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime: current == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(current),
        );
        if (time == null) return;
        String two(int n) => n.toString().padLeft(2, '0');
        widget.onChanged('${ymd(day)}T${two(time.hour)}:${two(time.minute)}');
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = widget.p;
    switch (_kind) {
      case _Kind.boolean:
        final on = widget.value == true;
        final change = widget.readOnly ? null : (bool b) => widget.onChanged(b);
        return MergeSemantics(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_label),
            subtitle: widget.error != null
                ? Text(widget.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                : (widget.hint == null ? null : Text(widget.hint!)),
            trailing: LiquidSwitch(value: on, onChanged: change),
            enabled: change != null,
            onTap: change == null ? null : () => change(!on),
          ),
        );
      case _Kind.text:
      case _Kind.textarea:
      case _Kind.number:
        return TextField(
          controller: _text,
          readOnly: widget.readOnly,
          minLines: _kind == _Kind.textarea ? 3 : 1,
          maxLines: _kind == _Kind.textarea ? 8 : 1,
          keyboardType: switch (_kind) {
            _Kind.textarea => TextInputType.multiline,
            _Kind.number => TextInputType.numberWithOptions(decimal: p.dataType == 'decimal', signed: true),
            _ => p.renderType == 'email' ? TextInputType.emailAddress : TextInputType.text,
          },
          decoration: _decoration(l),
          onChanged: widget.onChanged,
        );
      case _Kind.other:
        return InputDecorator(
          decoration: _decoration(l).copyWith(filled: true, helperText: widget.hint ?? l.openOnWebTitle),
          isEmpty: _str.isEmpty,
          child: Text(_str, maxLines: 3, overflow: TextOverflow.ellipsis),
        );
      default:
        final text = _display(l);
        final canClear = !widget.readOnly && !p.isRequired && _str.isNotEmpty;
        final icon = switch (_kind) {
          _Kind.date || _Kind.datetime => Icons.calendar_today_outlined,
          _Kind.lookup => Icons.search,
          _ => Icons.arrow_drop_down,
        };
        return InkWell(
          onTap: widget.readOnly ? null : () => _pick(context),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: _decoration(
              l,
              suffix: canClear
                  ? IconButton(tooltip: l.clear, icon: const Icon(Icons.clear), onPressed: () => widget.onChanged(''))
                  : (widget.readOnly ? null : Icon(icon)),
            ),
            isEmpty: text.isEmpty,
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
    }
  }
}
