class DanmakuShieldMatcher {
  List<String> _sourceRules = const [];
  List<_CompiledShieldRule> _compiledRules = const [];

  String? match(
    String message,
    Iterable<String> rules, {
    void Function(String rule)? onInvalidRegex,
  }) {
    final currentRules = rules.toList(growable: false);
    if (currentRules.isEmpty) {
      _sourceRules = const [];
      _compiledRules = const [];
      return null;
    }
    if (!_sameRules(_sourceRules, currentRules)) {
      _sourceRules = List<String>.unmodifiable(currentRules);
      _compiledRules = _compileRules(currentRules, onInvalidRegex);
    }

    for (final rule in _compiledRules) {
      if (message.contains(rule.pattern)) {
        return rule.source;
      }
    }
    return null;
  }

  List<_CompiledShieldRule> _compileRules(
    List<String> rules,
    void Function(String rule)? onInvalidRegex,
  ) {
    final result = <_CompiledShieldRule>[];
    for (final rule in rules) {
      if (_isRegexRule(rule)) {
        try {
          result.add(
            _CompiledShieldRule(
              source: rule,
              pattern: RegExp(rule.substring(1, rule.length - 1)),
            ),
          );
        } on FormatException {
          onInvalidRegex?.call(rule);
        }
      } else if (rule.isNotEmpty) {
        result.add(_CompiledShieldRule(source: rule, pattern: rule));
      }
    }
    return List<_CompiledShieldRule>.unmodifiable(result);
  }
}

class _CompiledShieldRule {
  const _CompiledShieldRule({
    required this.source,
    required this.pattern,
  });

  final String source;
  final Pattern pattern;
}

bool _sameRules(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _isRegexRule(String rule) {
  return rule.length > 2 && rule.startsWith('/') && rule.endsWith('/');
}
