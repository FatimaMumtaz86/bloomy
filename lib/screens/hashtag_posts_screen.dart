import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../utils/hashtag_utils.dart';
import '../navigation/app_router.dart';
import 'profile_screen.dart';

class HashtagPostsScreen extends StatelessWidget {
  final String hashtag;

  const HashtagPostsScreen({
    super.key,
    required this.hashtag,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    final normalized = normalizeHashtag(hashtag);
    final postProvider = context.watch<PostProvider>();
    final userProvider = context.watch<UserProvider>();

    final posts = postProvider.posts
        .where((post) => !post.isAnonymous)
        .where((post) => postContainsHashtag(post, normalized))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(
          '#$normalized',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: posts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.local_offer_rounded,
                    size: 44,
                    color: AppColors.textLight,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No posts for this hashtag yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Try another hashtag or post this one first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 10 : 14,
                    10,
                    isCompact ? 10 : 14,
                    8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${posts.length} posts',
                        style: const TextStyle(
                          color: AppColors.textMed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 10 : 14,
                      0,
                      isCompact ? 10 : 14,
                      20,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => _HashtagPostCard(
                      post: posts[i],
                      author: userProvider.getUserById(posts[i].userId),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HashtagPostCard extends StatelessWidget {
  final PostModel post;
  final UserModel? author;

  const _HashtagPostCard({
    required this.post,
    required this.author,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final authorName =
        author?.displayName ?? post.username ?? author?.username ?? 'Unknown';
    final avatar = resolveAvatarImage(author?.avatarUrl ?? post.avatarUrl);
    final authorInitial = authorName.isNotEmpty
        ? authorName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lavender.withOpacity(0.14),
            blurRadius: 10,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, AppRoutes.post(post.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OtherUserProfileScreen(userId: post.userId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.lavenderLight,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(
                              authorInitial,
                              style: const TextStyle(
                                color: AppColors.deepPink,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(post.createdAt),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDark),
              ),
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.lavenderLight,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
