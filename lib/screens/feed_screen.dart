import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/bloomy_logo.dart';
import '../widgets/app_image.dart';
import '../widgets/comment_sheet.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/edit_post_sheet.dart';
import '../widgets/save_post_collection_sheet.dart';
import '../widgets/share_to_dm_sheet.dart';
import '../utils/hashtag_utils.dart';
import '../utils/soft_symbols.dart';
import 'global_search_screen.dart';
import 'profile_screen.dart';

enum _FeedFilter { forYou, following, anonymous }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final unreadNotifications = context.watch<NotificationProvider>().unreadCount;
    final unreadMessages = context.watch<ChatProvider>().unreadCount;
    final imageLayout = context.watch<MediaLayoutProvider>();
    final useContainOnWeb = kIsWeb && imageLayout.useContainOnWeb;
    
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const BloomyLogo(size: 32),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textDark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              );
            },
          ),
          if (kIsWeb)
            IconButton(
              icon: Icon(
                useContainOnWeb
                    ? Icons.fit_screen_rounded
                    : Icons.crop_rounded,
                color: AppColors.textDark,
              ),
              tooltip: useContainOnWeb ? 'Image mode: Fit' : 'Image mode: Fill',
              onPressed: () => context.read<MediaLayoutProvider>().toggleMode(),
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.forum_outlined, color: AppColors.textDark),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.dms);
                },
              ),
              if (unreadMessages > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      unreadMessages > 99 ? '99+' : unreadMessages.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications);
                },
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      unreadNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.deepPink,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.deepPink,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Following'),
            Tab(text: 'Anonymous'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PostList(filter: _FeedFilter.forYou),
          _PostList(filter: _FeedFilter.following),
          _PostList(filter: _FeedFilter.anonymous),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'feed_fab',
        onPressed: () => _showCreatePost(context),
        backgroundColor: AppColors.deepPink,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(preSelectedDestination: 'fyp'),
    );
  }
}

class _PostList extends StatefulWidget {
  final _FeedFilter filter;
  const _PostList({required this.filter});

  @override
  State<_PostList> createState() => _PostListState();
}

class _PostListState extends State<_PostList> {
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (_isFetchingMore) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels < threshold) {
      return;
    }

    final postProv = context.read<PostProvider>();
    if (!postProv.hasMoreFeed) {
      return;
    }

    _isFetchingMore = true;
    try {
      await postProv.loadMorePublicPosts();
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> _onRefresh() async {
    final postProv = context.read<PostProvider>();
    await context.read<UserProvider>().refresh();
    await postProv.reloadFeed(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProv = context.watch<UserProvider>();
    final postProv = context.watch<PostProvider>();
    
    if (auth.user == null) {
      return const _EmptyFeed();
    }

    List<PostModel> filteredPosts = [];

    switch (widget.filter) {
      case _FeedFilter.forYou:
        // Show only public non-anonymous content from public profiles.
        filteredPosts = postProv.posts.where((post) {
          if (post.isAnonymous) {
            return false;
          }

          final author = userProv.getUserById(post.userId);
          return author != null && author.isPublic && post.visibility == PostVisibility.public;
        }).toList();
        break;

      case _FeedFilter.following:
        // Show only followed users' non-anonymous posts.
        filteredPosts = postProv.posts.where((post) {
          if (post.isAnonymous) {
            return false;
          }

          if (!auth.user!.followingIds.contains(post.userId)) {
            return false;
          }

          if (post.visibility == PostVisibility.public ||
              post.visibility == PostVisibility.followersOnly) {
            return true;
          }
          
          return false;
        }).toList();
        break;

      case _FeedFilter.anonymous:
        // Show only anonymous posts
        filteredPosts = postProv.posts.where((p) => p.isAnonymous).toList();
        break;
    }

    // Sort by recency (newest first)
    filteredPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredPosts.isEmpty) return const _EmptyFeed();

    final hasMore = postProv.hasMoreFeed;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      backgroundColor: AppColors.white,
      color: AppColors.deepPink,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: filteredPosts.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= filteredPosts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.deepPink),
              ),
            );
          }
          return _PostCard(post: filteredPosts[i]);
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text(SoftSymbols.blossom, style: TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text('Nothing here yet', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('Be the first to share something beautiful', style: Theme.of(context).textTheme.bodyMedium),
    ]),
  );
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});
  static const double _postMediaAspectRatio = 4 / 5;

  bool _isRemoteAvatarUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('gs://');
  }

  ImageProvider<Object>? _resolveAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    if (_isRemoteAvatarUrl(avatarUrl)) {
      return NetworkImage(avatarUrl);
    }
    return null;
  }

  Future<void> _confirmDeletePost(
    BuildContext context,
    PostProvider postProvider,
    String postId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await postProvider.deletePost(postId);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  Future<void> _editPost(
    BuildContext context,
    PostModel post,
  ) async {
    final didSave = await showEditPostSheet(context: context, post: post);
    if (didSave != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final postProv = context.read<PostProvider>();
    final savedProv = context.watch<SavedPostProvider>();
    final userProv = context.watch<UserProvider>();
    final isLiked = post.likedByIds.contains(auth.user?.id ?? '');
    final isSaved = savedProv.isSaved(post.id);
    final isOwnPost = (auth.user?.id ?? '') == post.userId;
    final postUser = userProv.getUserById(post.userId);
    final postAuthorName = post.isAnonymous
      ? SoftSymbols.anonymous
      : (post.username?.isNotEmpty == true
        ? post.username!
        : (postUser?.displayName.isNotEmpty == true
          ? postUser!.displayName
          : (postUser?.username.isNotEmpty == true ? postUser!.username : 'Unknown')));
    final avatarLabel = post.isAnonymous
      ? SoftSymbols.blossom
      : (postAuthorName.isNotEmpty ? postAuthorName.substring(0, 1).toUpperCase() : '?');
    final avatarImage = post.isAnonymous ? null : _resolveAvatarImage(postUser?.avatarUrl);
    final imageLayout = context.watch<MediaLayoutProvider>();
    final useContainOnWeb = kIsWeb && imageLayout.useContainOnWeb;
    final mediaFit = useContainOnWeb ? BoxFit.contain : BoxFit.cover;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.lavender.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: post.isAnonymous ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtherUserProfileScreen(userId: post.userId),
                  ),
                );
              },
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.lavenderLight,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          avatarLabel,
                          style: const TextStyle(fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    postAuthorName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    _timeAgo(post.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ]),
                const Spacer(),
                if (isOwnPost)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPost(context, post);
                      }
                      if (value == 'delete') {
                        _confirmDeletePost(context, postProv, post.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit post'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete post'),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textLight),
                  )
                else
                  const Icon(Icons.more_horiz_rounded, color: AppColors.textLight),
              ]),
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.post(post.id)),
                child: Text(post.caption, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppColors.cream,
                  child: AspectRatio(
                    aspectRatio: _postMediaAspectRatio,
                    child: AppImage(
                      imageUrl: post.imageUrl,
                      width: double.infinity,
                      fit: mediaFit,
                    ),
                  ),
                ),
              ),
            ),
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                children: post.tags.map((t) {
                  final normalized = normalizeHashtag(t);
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: normalized.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
                              context,
                              AppRoutes.hashtag(normalized),
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$normalized',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.lavenderDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              IconButton(
                onPressed: () async {
                  if (isLiked) {
                    await postProv.unlikePost(post.id, auth.user?.id ?? '');
                  } else {
                    // Create like notification
                    if (post.userId != auth.user?.id && post.userId.isNotEmpty) {
                      await context.read<NotificationProvider>().createNotification(
                        toUserId: post.userId,
                        fromUserId: auth.user?.id ?? '',
                        type: NotificationType.like,
                        postId: post.id,
                      );
                    }
                    await postProv.likePost(post.id, auth.user?.id ?? '');
                  }
                },
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.deepPink : AppColors.textLight,
                ),
              ),
              Text('${post.likedByIds.length}', style: const TextStyle(color: AppColors.textMed, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentSheet(post: post),
                  );
                },
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textLight),
              ),
              const SizedBox(width: 6),
              Text('${post.commentCount}', style: const TextStyle(color: AppColors.textMed, fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ShareToDmSheet(post: post),
                  );
                },
                icon: const Icon(Icons.send_rounded, color: AppColors.textLight),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => showSavePostCollectionSheet(
                  context: context,
                  post: post,
                  postId: post.id,
                ),
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? AppColors.deepPink : AppColors.textLight,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
