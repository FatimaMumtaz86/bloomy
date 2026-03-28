import '../models/models.dart';

final RegExp _hashtagPattern = RegExp(r'#([A-Za-z0-9_]+)');

String normalizeHashtag(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.startsWith('#')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

Set<String> extractHashtagsFromCaption(String caption) {
  final matches = _hashtagPattern.allMatches(caption);
  final hashtags = <String>{};
  for (final match in matches) {
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) {
      continue;
    }
    hashtags.add(normalizeHashtag(raw));
  }
  return hashtags;
}

Set<String> hashtagsForPost(PostModel post) {
  final tags = post.tags.map(normalizeHashtag).where((tag) => tag.isNotEmpty);
  return <String>{...tags, ...extractHashtagsFromCaption(post.caption)};
}

bool postContainsHashtag(PostModel post, String hashtag) {
  final normalized = normalizeHashtag(hashtag);
  if (normalized.isEmpty) {
    return false;
  }
  return hashtagsForPost(post).contains(normalized);
}

Map<String, int> hashtagCounts({
  required Iterable<PostModel> posts,
}) {
  final counts = <String, int>{};
  for (final post in posts) {
    for (final hashtag in hashtagsForPost(post)) {
      counts[hashtag] = (counts[hashtag] ?? 0) + 1;
    }
  }
  return counts;
}
