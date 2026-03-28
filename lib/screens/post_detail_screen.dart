import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../navigation/app_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../utils/hashtag_utils.dart';
import '../widgets/app_image.dart';
import '../widgets/comment_sheet.dart';
import '../widgets/edit_post_sheet.dart';
import '../widgets/save_post_collection_sheet.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({required this.postId, super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const double _postMediaAspectRatio = 4 / 5;

  PostModel? _post;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fetched =
          await context.read<PostProvider>().fetchPostById(widget.postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _post = fetched;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) {
      return;
    }

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
      await context.read<PostProvider>().deletePost(post.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }

  Future<void> _editPost() async {
    final post = _post;
    if (post == null) {
      return;
    }

    final didSave = await showEditPostSheet(context: context, post: post);
    if (didSave != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post updated.')),
    );
    await _loadPost();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.deepPink),
        ),
      );
    }

    if (_error != null || _post == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 46, color: AppColors.deepPink),
                const SizedBox(height: 12),
                const Text(
                  'This post is unavailable',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Post not found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMed),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadPost,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final post = _post!;
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final postProvider = context.read<PostProvider>();
    final savedProvider = context.watch<SavedPostProvider>();
    final mediaLayout = context.watch<MediaLayoutProvider>();
    final useContainOnWeb = kIsWeb && mediaLayout.useContainOnWeb;
    final mediaFit = useContainOnWeb ? BoxFit.contain : BoxFit.cover;

    final author = userProvider.getUserById(post.userId);
    final username = post.isAnonymous
        ? 'Anonymous'
        : (author?.username ?? post.username ?? 'unknown');
    final displayName = post.isAnonymous
        ? 'Anonymous'
        : (author?.displayName ?? post.username ?? 'Unknown user');
    final avatarImage = post.isAnonymous
        ? null
        : resolveAvatarImage(author?.avatarUrl ?? post.avatarUrl);

    final currentUserId = auth.user?.id ?? '';
    final isLiked =
        currentUserId.isNotEmpty && post.likedByIds.contains(currentUserId);
    final isSaved = savedProvider.isSaved(post.id);
    final isOwnPost = post.userId == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text(
          'Post',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isOwnPost)
            IconButton(
              onPressed: _editPost,
              icon: const Icon(Icons.edit_outlined, color: AppColors.deepPink),
              tooltip: 'Edit post',
            ),
          if (isOwnPost)
            IconButton(
              onPressed: _deletePost,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.deepPink),
              tooltip: 'Delete post',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPost,
        color: AppColors.deepPink,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lavender.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: post.isAnonymous
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OtherUserProfileScreen(userId: post.userId),
                              ),
                            );
                          },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.lavenderLight,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(
                                  post.isAnonymous
                                      ? 'A'
                                      : (displayName.isNotEmpty
                                          ? displayName
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : '?'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepPink,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    post.caption,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
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
                  ],
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: post.tags
                          .map(
                            (tag) => Container(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.hashtag(normalizeHashtag(tag)),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.lavenderLight,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '#${normalizeHashtag(tag)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.lavenderDeep,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: currentUserId.isEmpty
                            ? null
                            : () async {
                                if (isLiked) {
                                  await postProvider.unlikePost(
                                      post.id, currentUserId);
                                } else {
                                  await postProvider.likePost(
                                      post.id, currentUserId);
                                }
                                await _loadPost();
                              },
                        icon: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked
                              ? AppColors.deepPink
                              : AppColors.textLight,
                        ),
                      ),
                      Text(
                        '${post.likedByIds.length}',
                        style: const TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CommentSheet(post: post),
                          ).whenComplete(_loadPost);
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: AppColors.textLight),
                      ),
                      Text(
                        '${post.commentCount}',
                        style: const TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => showSavePostCollectionSheet(
                          context: context,
                          post: post,
                          postId: post.id,
                        ),
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved
                              ? AppColors.deepPink
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
