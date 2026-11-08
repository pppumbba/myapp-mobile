bool _bool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
int? _int(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
Map<String, dynamic>? _mapOrNull(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

class Meta {
  final int id;
  final String? code;
  final String? name;
  final String? type;
  final Map<String, dynamic> jsonConfig;
  final int? refMetaId;
  final String? tableName;
  final Map<String, String?> scripts;

  Meta({
    required this.id,
    this.code,
    this.name,
    this.type,
    this.jsonConfig = const {},
    this.refMetaId,
    this.tableName,
    this.scripts = const {},
  });

  static const scriptKeys = [
    'load_expression_string',
    'event_expression_string',
    'before_save_expression_string',
    'after_save_expression_string',
    'var_fnc_expression_string',
  ];

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        id: _int(j['id'])!,
        code: j['code'] as String?,
        name: j['name'] as String?,
        // The API sends the meta type as an object {id, code, name}; a plain code is accepted too.
        type: j['type'] is Map ? (j['type'] as Map)['code'] as String? : j['type'] as String?,
        jsonConfig: _map(j['json_config']),
        refMetaId: _int(j['ref_meta_id']),
        tableName: j['table_name'] as String?,
        scripts: {for (final k in scriptKeys) k: j[k] as String?},
      );
}

class MetaParam {
  final int id;
  final int? parentId;
  final int? refMetaId;
  final int orderNumber;
  final String? fieldPath;
  final String paramName;
  final String? labelName;
  final String? dataType;
  final String? renderType;
  final String? iconCls;
  final bool isShow;
  final bool isRequired;
  final bool isCriteria;
  final bool isMandatoryCriteria;
  final bool isLabel;
  final bool isSelect;
  final String? displayAs;
  final bool isPrimary;
  final String? widgetPosition;
  final String? displayField;
  final String? valueField;
  final Map<String, dynamic>? filterAs;
  final String? defaultValue;
  final Map<String, dynamic> jsonConfig;
  final List<MetaParam> children;

  MetaParam({
    required this.id,
    this.parentId,
    this.refMetaId,
    this.orderNumber = 0,
    this.fieldPath,
    required this.paramName,
    this.labelName,
    this.dataType,
    this.renderType,
    this.iconCls,
    this.isShow = true,
    this.isRequired = false,
    this.isCriteria = false,
    this.isMandatoryCriteria = false,
    this.isLabel = false,
    this.isSelect = false,
    this.displayAs,
    this.isPrimary = false,
    this.widgetPosition,
    this.displayField,
    this.valueField,
    this.filterAs,
    this.defaultValue,
    this.jsonConfig = const {},
    this.children = const [],
  });

  String get label => labelName ?? paramName;

  factory MetaParam.fromJson(Map<String, dynamic> j) => MetaParam(
        id: _int(j['id'])!,
        parentId: _int(j['parent_id']),
        refMetaId: _int(j['ref_meta_id']),
        orderNumber: _int(j['order_number']) ?? 0,
        fieldPath: j['field_path'] as String?,
        paramName: (j['param_name'] ?? '') as String,
        labelName: j['label_name'] as String?,
        dataType: j['data_type'] as String?,
        renderType: j['render_type'] as String?,
        iconCls: j['icon_cls'] as String?,
        isShow: j.containsKey('is_show') ? _bool(j['is_show']) : true,
        isRequired: _bool(j['is_required']),
        isCriteria: _bool(j['is_criteria']),
        isMandatoryCriteria: _bool(j['is_mandatory_criteria']),
        isLabel: _bool(j['is_label']),
        isSelect: _bool(j['is_select']),
        displayAs: j['display_as'] as String?,
        isPrimary: _bool(j['is_primary']),
        widgetPosition: j['widget_position'] as String?,
        displayField: j['display_field'] as String?,
        valueField: j['value_field'] as String?,
        filterAs: _mapOrNull(j['filter_as']),
        defaultValue: j['default_value']?.toString(),
        jsonConfig: _map(j['json_config']),
        children: [
          for (final c in (j['children'] as List? ?? const [])) MetaParam.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
      );
}

class MetaAction {
  final int id;
  final int? gridMetaId;
  final String? action;
  final String? label;
  final String? iconCls;
  final int? formMetaId;
  final int? getMetaId;
  final bool needsRow;
  final bool showInToolbar;
  final bool showInRow;
  final int orderNumber;
  final Map<String, String> params;

  MetaAction({
    required this.id,
    this.gridMetaId,
    this.action,
    this.label,
    this.iconCls,
    this.formMetaId,
    this.getMetaId,
    this.needsRow = false,
    this.showInToolbar = false,
    this.showInRow = false,
    this.orderNumber = 0,
    this.params = const {},
  });

  factory MetaAction.fromJson(Map<String, dynamic> j) {
    final p = _map(_map(j['json_config'])['params']);
    return MetaAction(
      id: _int(j['id'])!,
      gridMetaId: _int(j['grid_meta_id']),
      action: j['action'] as String?,
      label: j['label'] as String?,
      iconCls: j['icon_cls'] as String?,
      formMetaId: _int(j['form_meta_id']),
      getMetaId: _int(j['get_meta_id']),
      needsRow: _bool(j['needs_row']),
      showInToolbar: _bool(j['show_in_toolbar']),
      showInRow: _bool(j['show_in_row']),
      orderNumber: _int(j['order_number']) ?? 0,
      params: {for (final e in p.entries) e.key: '${e.value}'},
    );
  }
}

class DataPage {
  final List<Map<String, dynamic>> rows;
  final int currentPage;
  final int lastPage;
  final int total;
  final Map<String, dynamic> footer;
  final List<String> missingFilters;

  DataPage({
    required this.rows,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.footer = const {},
    this.missingFilters = const [],
  });

  factory DataPage.fromJson(Map<String, dynamic> j) {
    final rows = [for (final r in (j['data'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    return DataPage(
      rows: rows,
      currentPage: _int(j['current_page']) ?? 1,
      lastPage: _int(j['last_page']) ?? 1,
      total: _int(j['total']) ?? rows.length,
      footer: _map(j['footer']),
      missingFilters: [for (final f in (j['missing_filters'] as List? ?? const [])) '$f'],
    );
  }
}

class Access {
  final bool isAdmin;
  final Map<String, Map<String, bool>> metas;

  Access({this.isAdmin = false, this.metas = const {}});

  factory Access.fromJson(Map<String, dynamic> j) {
    final m = j['metas'];
    return Access(
      isAdmin: _bool(j['is_admin']),
      // PHP encodes an empty map as [], so anything that is not a Map counts as empty.
      metas: {
        if (m is Map)
          for (final e in m.entries)
            '${e.key}': {
              if (e.value is Map) for (final a in (e.value as Map).entries) '${a.key}': _bool(a.value),
            },
      },
    );
  }

  bool can(int? metaId, String ability) {
    if (isAdmin || metaId == null) return true;
    return metas['$metaId']?[ability] ?? false;
  }
}
