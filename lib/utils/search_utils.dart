String normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

List<String> searchTokens(String query) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
}

bool matchesSearchTokens({
  required String haystack,
  required List<String> tokens,
}) {
  if (tokens.isEmpty) {
    return true;
  }

  final normalizedHaystack = normalizeSearchText(haystack);
  if (normalizedHaystack.isEmpty) {
    return false;
  }

  for (final token in tokens) {
    if (!normalizedHaystack.contains(token)) {
      return false;
    }
  }
  return true;
}

bool matchesAnySearchField({
  required List<String> fields,
  required List<String> tokens,
}) {
  if (tokens.isEmpty) {
    return true;
  }

  for (final field in fields) {
    if (matchesSearchTokens(haystack: field, tokens: tokens)) {
      return true;
    }
  }
  return false;
}
