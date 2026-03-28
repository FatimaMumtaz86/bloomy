import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../navigation/app_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../utils/hashtag_utils.dart';
import '../utils/search_utils.dart';
import 'pin_detail_screen.dart';
import 'profile_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    final userProvider = context.watch<UserProvider>();
    final postProvider = context.watch<PostProvider>();
    final pinProvider = context.watch<PinProvider>();

    final tokens = searchTokens(_query);
    final users = tokens.isEmpty
        ? <UserModel>[]
        : userProvider.searchUsers(_query).take(20).toList();

    final posts = tokens.isEmpty
        ? <PostModel>[]
        : postProvider.posts
            .where((post) {
              if (post.isAnonymous) {
                return false;
              }
              return matchesAnySearchField(
                fields: <String>[
                  post.caption,
                  post.username ?? '',
                  post.tags.join(' '),
                ],
                tokens: tokens,
              );
            })
            .take(20)
            .toList();

    final pins = tokens.isEmpty
        ? <PinModel>[]
        : pinProvider.pins
            .where((pin) {
              return matchesAnySearchField(
                fields: <String>[
                  pin.title,
                  pin.description ?? '',
                  pin.username ?? '',
                  pin.tags.join(' '),
                ],
                tokens: tokens,
              );
            })
            .take(20)
            .toList();

    final hashtags = tokens.isEmpty
        ? <MapEntry<String, int>>[]
        : hashtagCounts(
            posts: postProvider.posts.where((post) => !post.isAnonymous),
          ).entries.where((entry) {
            return matchesAnySearchField(
              fields: <String>[entry.key],
              tokens: tokens,
            );
          }).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'Search',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 16,
              8,
              isCompact ? 12 : 16,
              10,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search users, posts, pins, hashtags...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: tokens.isEmpty
                ? const Center(
                    child: Text(
                      'Type to search users, posts, pins and hashtags',
                      style: TextStyle(color: AppColors.textMed),
                    ),
                  )
                : (users.isEmpty && posts.isEmpty && pins.isEmpty && hashtags.isEmpty)
                    ? const Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(color: AppColors.textMed),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 12 : 16,
                          0,
                          isCompact ? 12 : 16,
                          24,
                        ),
                        children: [
                          if (hashtags.isNotEmpty) ...[
                            _SectionTitle(
                              title: 'Hashtags',
                              count: hashtags.length,
                            ),
                            ...hashtags.take(20).map((entry) {
                              return _ResultTile(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: const Icon(
                                    Icons.tag_rounded,
                                    color: AppColors.deepPink,
                                  ),
                                  title: Text(
                                    '#${entry.key}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${entry.value} posts',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.hashtag(entry.key),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (users.isNotEmpty) ...[
                            _SectionTitle(title: 'Users', count: users.length),
                            ...users.map((user) {
                              final avatarImage =
                                  resolveAvatarImage(user.avatarUrl);
                              final avatarInitial = user.displayName.isNotEmpty
                                  ? user.displayName
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?';

                              return _ResultTile(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.lavenderLight,
                                    backgroundImage: avatarImage,
                                    child: avatarImage == null
                                        ? Text(
                                            avatarInitial,
                                            style: const TextStyle(
                                                color: AppColors.deepPink),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '@${user.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OtherUserProfileScreen(userId: user.id),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (posts.isNotEmpty) ...[
                            _SectionTitle(title: 'Posts', count: posts.length),
                            ...posts.map((post) {
                              final author =
                                  userProvider.getUserById(post.userId);
                              final authorName = author?.displayName ??
                                  post.username ??
                                  'Unknown';
                              final authorUsername =
                                  author?.username ?? post.username ?? 'user';
                              final avatarImage = resolveAvatarImage(
                                  author?.avatarUrl ?? post.avatarUrl);
                              final avatarInitial = authorName.isNotEmpty
                                  ? authorName.substring(0, 1).toUpperCase()
                                  : '?';

                              return _ResultTile(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OtherUserProfileScreen(
                                            userId: post.userId),
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: AppColors.lavenderLight,
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? Text(
                                              avatarInitial,
                                              style: const TextStyle(
                                                  color: AppColors.deepPink),
                                            )
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    post.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      Text(
                                    '$authorName · @$authorUsername',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.post(post.id),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (pins.isNotEmpty) ...[
                            _SectionTitle(title: 'Pins', count: pins.length),
                            ...pins.map((pin) {
                              final author =
                                  userProvider.getUserById(pin.userId);
                              final authorName = author?.displayName ??
                                  pin.username ??
                                  'Unknown';
                              final authorUsername =
                                  author?.username ?? pin.username ?? 'user';
                              final avatarImage =
                                  resolveAvatarImage(author?.avatarUrl);
                              final avatarInitial = authorName.isNotEmpty
                                  ? authorName.substring(0, 1).toUpperCase()
                                  : '?';

                              return _ResultTile(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OtherUserProfileScreen(
                                            userId: pin.userId),
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: AppColors.lavenderLight,
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? Text(
                                              avatarInitial,
                                              style: const TextStyle(
                                                  color: AppColors.deepPink),
                                            )
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    pin.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      Text(
                                    '$authorName · @$authorUsername',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PinDetailScreen(pin: pin),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lavenderLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textMed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Widget child;

  const _ResultTile({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
