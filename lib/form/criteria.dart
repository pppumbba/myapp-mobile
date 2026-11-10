/// Port of the web `render/criteria.ts` (the browser's copy of App\Support\Criteria): reads expressions
/// like "roleId == 1 || appMetaId == 2 || supplierTypeId == 3" and never runs them as code. Numbers,
/// 'text' or "text", true/false/null, names, ( ), == != <> > < >= <= (a single = means ==), && || !
/// (also and/or/not), and + - * /. A name is looked up as written, then as snake_case, then ignoring
/// case. A list (roleId) matches with == when it holds the value. Mistakes throw a [CriteriaError].
library;

class CriteriaError implements Exception {
  final String message;
  CriteriaError(this.message);
  @override
  String toString() => message;
}

/// Whether the expression holds. An empty expression always does.
bool criteriaPasses(String? expression, Map<String, Object?> vars) {
  if (expression == null || expression.trim().isEmpty) return true;
  return _truthy(_Parser(expression, vars).run());
}

bool _truthy(Object? v) {
  if (v == null || v == false) return false;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

num? _asNum(Object? v) {
  if (v is num) return v.isFinite ? v : null;
  if (v is String && v.trim().isNotEmpty) {
    final n = num.tryParse(v.trim());
    return n != null && n.isFinite ? n : null;
  }
  return null;
}

bool _same(Object? left, Object? right) {
  // null matches only null or empty text, never 0.
  if (left == null || right == null) return (left ?? '') == (right ?? '');
  final l = _asNum(left), r = _asNum(right);
  if (l != null && r != null) return l == r;
  if (left is bool || right is bool) return _truthy(left) == _truthy(right);
  return '$left' == '$right';
}

String _str(Object? v) => v == null ? '' : '$v';

class _Token {
  final String kind; // num, str, lit, name, op
  final Object? value;
  const _Token(this.kind, this.value);
}

class _Parser {
  final Map<String, Object?> vars;
  final List<_Token> tokens;
  int pos = 0;
  _Parser(String expression, this.vars) : tokens = _tokenize(expression);

  Object? run() {
    final value = _or();
    if (_peek() != null) throw CriteriaError('Unexpected "${_peek()!.value}" in the criteria.');
    return value;
  }

  _Token? _peek() => pos < tokens.length ? tokens[pos] : null;

  String? _accept(List<String> ops) {
    final t = _peek();
    if (t != null && t.kind == 'op' && ops.contains(t.value)) {
      pos++;
      return t.value as String;
    }
    return null;
  }

  Object? _or() {
    var left = _and();
    while (_accept(['||']) != null) {
      final right = _and();
      left = _truthy(left) || _truthy(right);
    }
    return left;
  }

  Object? _and() {
    var left = _not();
    while (_accept(['&&']) != null) {
      final right = _not();
      left = _truthy(left) && _truthy(right);
    }
    return left;
  }

  Object? _not() => _accept(['!']) != null ? !_truthy(_not()) : _comparison();

  Object? _comparison() {
    final left = _sum();
    final op = _accept(['==', '!=', '>', '<', '>=', '<=']);
    if (op == null) return left;
    final right = _sum();
    if (op == '==' || op == '!=') {
      final bool equal;
      if (left is List && right is List) {
        equal = left.any((l) => right.any((r) => _same(l, r)));
      } else if (left is List) {
        equal = left.any((l) => _same(l, right));
      } else if (right is List) {
        equal = right.any((r) => _same(left, r));
      } else {
        equal = _same(left, right);
      }
      return op == '==' ? equal : !equal;
    }
    if (left is List || right is List) throw CriteriaError('A list (like roleId) can only be compared with == or !=.');
    final l = _asNum(left), r = _asNum(right);
    final order = l != null && r != null ? (l - r).sign : _str(left).compareTo(_str(right)).sign;
    return switch (op) { '>' => order > 0, '<' => order < 0, '>=' => order >= 0, _ => order <= 0 };
  }

  Object? _sum() {
    var left = _product();
    String? op;
    while ((op = _accept(['+', '-'])) != null) {
      final right = _product();
      left = op == '+' ? _num(left) + _num(right) : _num(left) - _num(right);
    }
    return left;
  }

  Object? _product() {
    var left = _unary();
    String? op;
    while ((op = _accept(['*', '/'])) != null) {
      final right = _num(_unary());
      if (op == '/' && right == 0) throw CriteriaError('The criteria divides by zero.');
      left = op == '*' ? _num(left) * right : _num(left) / right;
    }
    return left;
  }

  Object? _unary() => _accept(['-']) != null ? -_num(_unary()) : _primary();

  Object? _primary() {
    final t = _peek();
    if (t == null) throw CriteriaError('The criteria ends too early.');
    pos++;
    if (t.kind == 'op' && t.value == '(') {
      final value = _or();
      if (_accept([')']) == null) throw CriteriaError('The criteria is missing a closing ")".');
      return value;
    }
    if (t.kind == 'num' || t.kind == 'str' || t.kind == 'lit') return t.value;
    if (t.kind == 'name') return _lookup(t.value as String);
    throw CriteriaError('Unexpected "${t.value}" in the criteria.');
  }

  Object? _lookup(String name) {
    if (vars.containsKey(name)) return vars[name];
    final snake = name.replaceAllMapped(RegExp(r'(?<!^)[A-Z]'), (m) => '_${m[0]}').toLowerCase();
    if (vars.containsKey(snake)) return vars[snake];
    for (final k in vars.keys) {
      if (k.toLowerCase() == name.toLowerCase()) return vars[k];
    }
    throw CriteriaError('The criteria uses "$name", which this record doesn\'t have.');
  }

  num _num(Object? v) {
    final n = _asNum(v);
    if (n == null) throw CriteriaError('The criteria does arithmetic on something that is not a number.');
    return n;
  }
}

List<_Token> _tokenize(String s) {
  final tokens = <_Token>[];
  var i = 0;
  final number = RegExp(r'^\d*\.?\d+'), word = RegExp(r'^[A-Za-z_]\w*'), op = RegExp(r'^(==|!=|<>|>=|<=|&&|\|\||[=<>!()+\-*/])');
  while (i < s.length) {
    final rest = s.substring(i);
    final c = s[i];
    RegExpMatch? m;
    if (RegExp(r'\s').hasMatch(c)) {
      i++;
    } else if ((m = number.firstMatch(rest)) != null) {
      tokens.add(_Token('num', num.parse(m![0]!)));
      i += m[0]!.length;
    } else if (c == "'" || c == '"') {
      final end = s.indexOf(c, i + 1);
      if (end < 0) throw CriteriaError('A text value in the criteria is missing its closing quote.');
      tokens.add(_Token('str', s.substring(i + 1, end)));
      i = end + 1;
    } else if ((m = word.firstMatch(rest)) != null) {
      final w = m![0]!;
      tokens.add(switch (w.toLowerCase()) {
        'and' => const _Token('op', '&&'),
        'or' => const _Token('op', '||'),
        'not' => const _Token('op', '!'),
        'true' => const _Token('lit', true),
        'false' => const _Token('lit', false),
        'null' => const _Token('lit', null),
        _ => _Token('name', w),
      });
      i += w.length;
    } else if ((m = op.firstMatch(rest)) != null) {
      final o = m![0]!;
      tokens.add(_Token('op', o == '=' ? '==' : (o == '<>' ? '!=' : o)));
      i += o.length;
    } else {
      throw CriteriaError('The criteria can\'t use "$c".');
    }
  }
  return tokens;
}
