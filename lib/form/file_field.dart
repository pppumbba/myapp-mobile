import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart' show apiClientProvider;
import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import '../widgets/pull_refresh.dart' show RefreshRing;
import '../widgets/row_group.dart';
import '../widgets/snap_sheet.dart';
import 'values.dart' show filesOf;

/// Extensions the server never takes (it says so too; this saves the upload).
const _blocked = {'php', 'phtml', 'phar', 'exe', 'bat', 'cmd', 'sh', 'js', 'mjs', 'html', 'htm', 'svg', 'xhtml', 'jar', 'msi', 'com', 'scr', 'vbs', 'ps1'};
const _images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};

/// A file field's settings (json_config): allowed extensions, size limit, how many.
class FileRules {
  final List<String> accept; // lower case, no dot; empty = anything not blocked
  final int maxKb;
  final int maxFiles;
  const FileRules({this.accept = const [], this.maxKb = 20480, this.maxFiles = 20});

  factory FileRules.of(MetaParam p) {
    final c = p.jsonConfig;
    return FileRules(
      accept: [if (c['accept'] is List) for (final e in c['accept'] as List) '$e'.toLowerCase().replaceFirst('.', '')],
      maxKb: (c['max_size'] as num?)?.toInt() ?? 20480,
      maxFiles: p.dataType == 'singlefile' ? 1 : ((c['max_files'] as num?)?.toInt() ?? 20),
    );
  }

  bool get takesImages => accept.isEmpty || accept.any(_images.contains);

  /// Why [name] of [bytes] can't go, or null.
  String? problem(String name, int bytes, AppLocalizations l) {
    final ext = extOf(name);
    if (_blocked.contains(ext) || (accept.isNotEmpty && !accept.contains(ext))) {
      return l.fileTypeNotAllowed(name, accept.isEmpty ? '' : accept.join(', '));
    }
    if (bytes > maxKb * 1024) return l.fileTooBig(name, sizeText(maxKb * 1024));
    return null;
  }
}

String extOf(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

/// 1.2 MB, 340 KB.
String sizeText(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

IconData fileIcon(String ext) => switch (ext) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => Icons.description_outlined,
      'xls' || 'xlsx' || 'ods' || 'csv' => Icons.table_chart_outlined,
      'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

/// A file on its way up: a picked file, then its upload's progress or error.
class _Pending {
  final String path, name;
  final int bytes;
  double progress = 0;
  String? error;
  _Pending(this.path, this.name, this.bytes);
}

/// A form's file field as a row block entry: the label with Add, then the files (tap one to open
/// it, × to take it off). Picked files upload at once (POST /metas/{form}/files) and join the
/// value when they are in; the form saves them onto the record. [onBusy] says whether any upload
/// is still going, so the form can wait for it.
class FileField extends ConsumerStatefulWidget {
  final MetaParam p;
  final int formMetaId;
  final Object? value;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onBusy;
  final bool readOnly;
  final String? error;
  const FileField({
    super.key,
    required this.p,
    required this.formMetaId,
    required this.value,
    required this.onChanged,
    required this.onBusy,
    this.readOnly = false,
    this.error,
  });

  @override
  ConsumerState<FileField> createState() => _FileFieldState();
}

class _FileFieldState extends ConsumerState<FileField> {
  final _pending = <_Pending>[];
  String? _note; // a picked file that couldn't go
  String? _opening; // id of the file being fetched to open

  late FileRules _rules = FileRules.of(widget.p);

  @override
  void didUpdateWidget(FileField old) {
    super.didUpdateWidget(old);
    if (old.p != widget.p) _rules = FileRules.of(widget.p);
    if (old.value != widget.value) _sent = null;
  }

  /// The files just handed to [FileField.onChanged], until the form passes them back: two uploads
  /// finishing in one frame must both land.
  List<Map<String, dynamic>>? _sent;

  List<Map<String, dynamic>> get _files => _sent ?? filesOf(widget.value);
  /// How many more files may be picked. A single-file field always has room: the new one replaces.
  int get _room => _rules.maxFiles == 1 ? 1 : _rules.maxFiles - _files.length - _pending.where((x) => x.error == null).length;

  void _set(List<Map<String, dynamic>> files) {
    _sent = files;
    widget.onChanged(files.isEmpty ? '' : jsonEncode(files));
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final how = await showSnapSheet<String>(
      context,
      initial: SnapHeight.peek,
      builder: (ctx) => ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(ctx).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(widget.p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.titleLarge),
          ),
          RowGroup(children: [
            if (_rules.takesImages) ...[
              IconRow(icon: Icons.photo_camera_outlined, title: l.takePhoto, onTap: () => Navigator.of(ctx).pop('camera')),
              IconRow(icon: Icons.photo_library_outlined, title: l.photoLibrary, onTap: () => Navigator.of(ctx).pop('photos')),
            ],
            IconRow(icon: Icons.folder_open_outlined, title: l.browseFiles, onTap: () => Navigator.of(ctx).pop('files')),
          ]),
          if (_rules.accept.isNotEmpty || _rules.maxKb != 20480)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                [if (_rules.accept.isNotEmpty) _rules.accept.join(', '), l.upTo(sizeText(_rules.maxKb * 1024))].join(' · '),
                style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
    if (how == null || !mounted) return;
    final picked = <(String path, String name)>[];
    try {
      if (how == 'camera') {
        // Photos are scaled down a little: phone pictures easily pass a 10 MB limit.
        final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2560, imageQuality: 85);
        if (x != null) picked.add((x.path, x.name));
      } else if (how == 'photos') {
        final many = _room > 1;
        final xs = many
            ? await ImagePicker().pickMultiImage(maxWidth: 2560, imageQuality: 85, limit: _room)
            : [?await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2560, imageQuality: 85)];
        picked.addAll([for (final x in xs) (x.path, x.name)]);
      } else {
        final type = _rules.accept.isEmpty ? FileType.any : FileType.custom;
        final exts = _rules.accept.isEmpty ? null : _rules.accept;
        final files = _room > 1
            ? await FilePicker.pickFiles(type: type, allowedExtensions: exts)
            : [?await FilePicker.pickFile(type: type, allowedExtensions: exts)];
        picked.addAll([for (final f in files) if (f.path != null) (f.path!, f.name)]);
      }
    } catch (_) {
      if (mounted) setState(() => _note = l.couldNotPick);
      return;
    }
    if (!mounted || picked.isEmpty) return;
    String? note;
    final go = <_Pending>[];
    final room = _room;
    for (final (path, name) in picked) {
      if (go.length >= room) {
        note = l.fileLimit(_rules.maxFiles);
        break;
      }
      final bytes = await File(path).length();
      final why = _rules.problem(name, bytes, l);
      if (why != null) {
        note = why;
        continue;
      }
      go.add(_Pending(path, name, bytes));
    }
    // A single-file field swaps its file (and any upload still going) for the new one.
    if (_rules.maxFiles == 1 && go.isNotEmpty) {
      if (_files.isNotEmpty) _set(const []);
      _pending.clear();
    }
    setState(() {
      _note = note;
      _pending.addAll(go);
    });
    for (final x in go) {
      _upload(x);
    }
  }

  Future<void> _upload(_Pending x) async {
    widget.onBusy(true);
    setState(() {
      x.error = null;
      x.progress = 0;
    });
    try {
      final form = FormData.fromMap({
        'param_id': widget.p.id,
        'file': await MultipartFile.fromFile(x.path, filename: x.name),
      });
      final info = await ref.read(apiClientProvider).upload<dynamic>(
        '/metas/${widget.formMetaId}/files',
        form,
        onProgress: (k) {
          if (mounted) setState(() => x.progress = k);
        },
      );
      // Taken off (or replaced) while it went up: the server's cleanup drops the orphan.
      if (!mounted || !_pending.contains(x)) return;
      setState(() => _pending.remove(x));
      if (info is Map) _set([..._files, Map<String, dynamic>.from(info)]);
    } on ApiError catch (e) {
      if (mounted && _pending.contains(x)) setState(() => x.error = e.message);
    } catch (_) {
      if (mounted && _pending.contains(x)) setState(() => x.error = AppLocalizations.of(context).somethingWrong);
    }
    if (mounted) widget.onBusy(_pending.any((p) => p.error == null));
  }

  void _remove(Map<String, dynamic> f) => _set([for (final x in _files) if ('${x['id']}' != '${f['id']}') x]);

  void _drop(_Pending x) {
    setState(() => _pending.remove(x));
    widget.onBusy(_pending.any((p) => p.error == null));
  }

  /// Fetches the file (signed in) to the phone's cache and opens it in the app made for it.
  Future<void> _open(Map<String, dynamic> f) async {
    final id = '${f['id']}';
    if (_opening != null) return;
    setState(() => _opening = id);
    final l = AppLocalizations.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final name = '${f['file_name'] ?? 'file'}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final to = '${dir.path}/files/$id/$name';
      if (!await File(to).exists()) {
        await File(to).parent.create(recursive: true);
        await ref.read(apiClientProvider).download('/contents/$id', to);
      }
      final r = await OpenFilex.open(to);
      if (r.type != ResultType.done && mounted) {
        setState(() => _note = r.type == ResultType.noAppToOpen ? l.noAppToOpen : r.message);
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _note = e.message);
    } catch (_) {
      if (mounted) setState(() => _note = l.somethingWrong);
    }
    if (mounted) setState(() => _opening = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = widget.p;
    final required = p.isRequired;
    final error = widget.error;
    final files = _files;
    final canAdd = !widget.readOnly && _room > 0;
    final note = error ?? _note;

    Widget square(IconData icon, {Color? color}) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: (color ?? pillViolet).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 19, color: color ?? pillViolet),
        );
    Widget fileRow({
      required Widget lead,
      required String name,
      required String sub,
      Color? subColor,
      Widget? trailing,
      VoidCallback? onTap,
      double? progress,
    }) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            child: Row(children: [
              lead,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(value: progress, minHeight: 3, color: pillCyan, backgroundColor: pillViolet.withValues(alpha: 0.2)),
                      ),
                    )
                  else
                    Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: subColor ?? scheme.onSurfaceVariant)),
                ]),
              ),
              ?trailing,
            ]),
          ),
        );
    Widget iconButton(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          onPressed: onTap,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      // The label row, like the other fields, with Add at the right.
      InkWell(
        onTap: canAdd ? _add : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(children: [
              Expanded(
                child: Text(required ? '${p.label} *' : p.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: error != null ? scheme.error : scheme.onSurfaceVariant)),
              ),
              if (files.isEmpty && _pending.isEmpty)
                Text(widget.readOnly ? l.noFiles : '', style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant.withValues(alpha: 0.55))),
              if (canAdd)
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(_rules.maxFiles == 1 && files.isNotEmpty ? l.replaceFile : l.addFile),
                  style: TextButton.styleFrom(foregroundColor: pillCyan),
                ),
            ]),
          ),
        ),
      ),
      for (final f in files)
        fileRow(
          lead: _opening == '${f['id']}'
              ? const SizedBox.square(dimension: 36, child: Center(child: RefreshRing(size: 22)))
              : square(fileIcon('${f['file_extension'] ?? extOf('${f['file_name']}')}')),
          name: '${f['file_name'] ?? ''}',
          sub: [
            if (f['file_size'] is num) sizeText((f['file_size'] as num).toInt()),
            if ('${f['description'] ?? ''}'.isNotEmpty) '${f['description']}',
          ].join(' · '),
          onTap: () => _open(f),
          trailing: widget.readOnly ? null : iconButton(Icons.close_rounded, l.removeFile, () => _remove(f)),
        ),
      for (final x in _pending)
        fileRow(
          lead: square(x.error == null ? fileIcon(extOf(x.name)) : Icons.error_outline, color: x.error == null ? null : scheme.error),
          name: x.name,
          sub: x.error ?? sizeText(x.bytes),
          subColor: x.error == null ? null : scheme.error,
          progress: x.error == null ? x.progress : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (x.error != null) iconButton(Icons.refresh_rounded, l.retry, () => _upload(x)),
            iconButton(Icons.close_rounded, l.removeFile, () => _drop(x)),
          ]),
        ),
      if (note != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text(note, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: error != null || _note != null ? scheme.error : scheme.onSurfaceVariant)),
        ),
    ]);
  }
}
