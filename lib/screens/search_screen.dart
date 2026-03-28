import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../utils/hashtag_utils.dart';
import '../utils/soft_symbols.dart';
import '../utils/search_utils.dart';
import '../widgets/cross_platform_image.dart';
import '../widgets/save_post_collection_sheet.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context.read<UserProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width <= 360;
    final userProv = context.watch<UserProvider>();
    final postProv = context.watch<PostProvider>();

    final tokens = searchTokens(_query);
    final userResults = userProv.searchUsers(_query);
    final postResults = tokens.isEmpty
        ? <PostModel>[]
        : postProv.posts
            .where((post) => !post.isAnonymous)
            .where(
              (post) => matchesAnySearchField(
                fields: <String>[
                  post.caption,
                  post.username ?? '',
                  post.tags.join(' '),
                ],
                tokens: tokens,
              ),
            )
            .take(20)
            .toList();

    final hashtagCountMap = hashtagCounts(
      posts: postProv.posts.where((post) => !post.isAnonymous),
    );
    final hashtagResults = tokens.isEmpty
        ? <MapEntry<String, int>>[]
        : hashtagCountMap.entries
            .where((entry) => matchesAnySearchField(
                  fields: <String>[entry.key],
                  tokens: tokens,
                ))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text('Discover',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 16,
              12,
              isCompact ? 12 : 16,
              10,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search users, posts, hashtags...',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.deepPink),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding:
                    EdgeInsets.symmetric(
                      horizontal: isCompact ? 14 : 16,
                      vertical: isCompact ? 10 : 12,
                    ),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.manage_search_rounded,
                          size: 44,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Search profiles, posts and hashtags',
                          style: TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : (userResults.isEmpty &&
                        postResults.isEmpty &&
                        hashtagResults.isEmpty)
                    ? Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 10 : 12,
                          0,
                          isCompact ? 10 : 12,
                          20,
                        ),
                        children: [
                          if (hashtagResults.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Hashtags',
                              count: hashtagResults.length,
                            ),
                            ...hashtagResults.take(20).map(
                                  (entry) => _ResultCard(
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
                                      title: Text('#${entry.key}'),
                                      subtitle: Text('${entry.value} posts'),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textLight,
                                      ),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.hashtag(entry.key),
                                      ),
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 8),
                          ],
                          if (postResults.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Posts',
                              count: postResults.length,
                            ),
                            ...postResults.map(
                              (post) => _ResultCard(
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: const Icon(
                                    Icons.article_outlined,
                                    color: AppColors.deepPink,
                                  ),
                                  title: Text(
                                    post.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    post.tags.isEmpty
                                        ? 'Open post'
                                        : post.tags
                                            .map((tag) => '#${normalizeHashtag(tag)}')
                                            .join(' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textLight,
                                  ),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.post(post.id),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (userResults.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Profiles',
                              count: userResults.length,
                            ),
                            ...userResults.map((user) => _UserCard(user: user)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
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

class _ResultCard extends StatelessWidget {
  final Widget child;

  const _ResultCard({required this.child});

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

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final avatarImage = resolveAvatarImage(user.avatarUrl);
    final avatarInitial = user.displayName.isNotEmpty
        ? user.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.lavender.withOpacity(0.15), blurRadius: 10)
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.lavenderLight,
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? Text(
                  avatarInitial,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepPink),
                )
              : null,
        ),
        title: Text(user.displayName,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMed),
              ),
            ),
            if (!user.isPublic) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_rounded,
                  size: 14, color: AppColors.textLight),
            ],
          ],
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtherUserProfileScreen(userId: user.id)),
        ),
      ),
    );
  }
}

class ViewProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ViewProfileScreen(
      {required this.userId, required this.userName, super.key});

  @override
  Widget build(BuildContext context) {
    final userProv = context.read<UserProvider>();
    final user = userProv.getUserById(userId);

    if (user == null || !user.isPublic) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(
          child: Text('This profile is private 🔒'),
        ),
      );
    }

    final postProv = context.watch<PostProvider>();
    final followProv = context.watch<FollowProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    final isFollowing =
        currentUserId.isNotEmpty && user.followerIds.contains(currentUserId);

    final userPosts = postProv.posts
        .where((p) => p.userId == userId && !p.isAnonymous)
        .toList();
    final avatarImage = resolveAvatarImage(user.avatarUrl);
    final avatarInitial = user.displayName.isNotEmpty
        ? user.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('@$userName',
            style: const TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.lavenderLight,
                    AppColors.softPink,
                    AppColors.cream
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.white,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            avatarInitial,
                            style: const TextStyle(
                                fontSize: 36,
                                color: AppColors.deepPink,
                                fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(user.displayName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  Text('@${user.username}',
                      style: const TextStyle(
                          color: AppColors.textMed, fontSize: 14)),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(user.bio!,
                        style: const TextStyle(
                            color: AppColors.textMed, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.deepPink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('🌍 Public Profile',
                        style: TextStyle(
                            color: AppColors.deepPink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  // Follow button
                  if (currentUserId != userId && currentUserId.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isFollowing) {
                            await followProv.unfollowUser(
                                currentUserId: currentUserId,
                                targetUserId: userId);
                          } else {
                            await followProv.followUser(
                                currentUserId: currentUserId,
                                targetUserId: userId);
                          }
                          await context.read<UserProvider>().refresh();
                          await context
                              .read<AuthProvider>()
                              .refreshCurrentUser();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? AppColors.white
                              : AppColors.deepPink,
                          side: BorderSide(
                              color: AppColors.deepPink,
                              width: isFollowing ? 2 : 0),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing
                                ? AppColors.deepPink
                                : AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatBox(value: '${userPosts.length}', label: 'Posts'),
                  const SizedBox(width: 12),
                  _StatBox(
                      value: '${user.followerIds.length}', label: 'Followers'),
                  const SizedBox(width: 12),
                  _StatBox(
                      value: '${user.followingIds.length}', label: 'Following'),
                ],
              ),
            ),
          ),
          if (userPosts.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 48,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text('No posts yet',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PostCard(post: userPosts[i]),
                childCount: userPosts.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final postProv = context.read<PostProvider>();
    final savedProv = context.watch<SavedPostProvider>();
    final isLiked = post.likes.contains(auth.user?.id ?? '');
    final isSaved = savedProv.isSaved(post.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.lavender.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.lavenderLight,
                child: Text(
                  post.isAnonymous
                      ? SoftSymbols.blossom
                      : (post.username?.substring(0, 1).toUpperCase() ?? '?'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        post.isAnonymous
                            ? 'Anonymous'
                            : (post.username ?? 'Unknown'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const Text('just now',
                        style:
                            TextStyle(color: AppColors.textMed, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(post.caption,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 14, height: 1.5)),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            CrossPlatformImage(
                filePath: post.imageUrl!,
                fit: BoxFit.cover,
                height: 200,
                width: double.infinity),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (isLiked) {
                      await postProv.unlikePost(post.id, auth.user?.id ?? '');
                    } else {
                      await postProv.likePost(post.id, auth.user?.id ?? '');
                    }
                  },
                  child: Icon(isLiked ? Icons.favorite : Icons.favorite_outline,
                      color: AppColors.deepPink, size: 24),
                ),
                const SizedBox(width: 8),
                Text('${post.likes.length}',
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 24),
                const Icon(Icons.chat_bubble_outline,
                    color: AppColors.textMed, size: 24),
                const SizedBox(width: 8),
                Text('${post.commentCount}',
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => showSavePostCollectionSheet(
                    context: context,
                    post: post,
                    postId: post.id,
                  ),
                  child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      color: AppColors.deepPink, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.lavender.withOpacity(0.15), blurRadius: 10)
            ]),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepPink)),
          Text(label,
              style: const TextStyle(color: AppColors.textMed, fontSize: 12)),
        ]),
      ));
}
