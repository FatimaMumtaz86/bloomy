import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../utils/soft_symbols.dart';
import '../screens/profile_screen.dart';

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

/// Bottom sheet for adding and viewing comments on a post
class CommentSheet extends StatefulWidget {
  final PostModel post;
  const CommentSheet({required this.post, super.key});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _commentCtrl = TextEditingController();
  final _commentFocusNode = FocusNode();
  final TranslationService _translationService = TranslationService();
  bool _isAnonymous = false;
  bool _isPosting = false;
  CommentModel? _replyingTo;
  final Set<String> _expandedReplyThreads = <String>{};
  final Map<String, String> _translatedTextByCommentId = <String, String>{};
  final Set<String> _translatingCommentIds = <String>{};
  final Set<String> _showOriginalCommentIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Load comments when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentProvider>().loadCommentsForPost(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _startReply(CommentModel comment, String? replyUsername) {
    final canMention = !widget.post.isAnonymous && !comment.isAnonymous;
    final mention = (canMention &&
            replyUsername != null &&
            replyUsername.isNotEmpty)
        ? '@$replyUsername '
        : '';

    setState(() {
      _replyingTo = comment;
      if (_commentCtrl.text.trim().isEmpty && mention.isNotEmpty) {
        _commentCtrl.text = mention;
      }
    });

    _commentCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentCtrl.text.length),
    );
    _commentFocusNode.requestFocus();
  }

  String? _safeReplyUsername(CommentModel comment) {
    if (widget.post.isAnonymous || comment.isAnonymous) {
      return null;
    }

    return context.read<UserProvider>().getUserById(comment.userId)?.username;
  }

  String _replyingLabel(CommentModel comment) {
    if (widget.post.isAnonymous || comment.isAnonymous) {
      return 'Replying anonymously';
    }

    final username =
        context.read<UserProvider>().getUserById(comment.userId)?.username;
    if (username == null || username.isEmpty) {
      return 'Replying to user';
    }

    return 'Replying to @$username';
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isPosting = true);

    try {
      final commentProv = context.read<CommentProvider>();
      final notifProv = context.read<NotificationProvider>();

      // Add comment
      await commentProv.addComment(
        postId: widget.post.id,
        userId: auth.user!.id,
        text: _commentCtrl.text.trim(),
        parentCommentId: _replyingTo?.parentCommentId?.isNotEmpty == true
            ? _replyingTo!.parentCommentId
            : _replyingTo?.id,
        isAnonymous: _isAnonymous,
      );

      await context.read<PostProvider>().reloadFeed(reset: true);

      // Create notification (if not commenting on own post)
      if (widget.post.userId != auth.user!.id) {
        await notifProv.createNotification(
          toUserId: widget.post.userId,
          fromUserId: auth.user!.id,
          type: NotificationType.comment,
          postId: widget.post.id,
        );
      }

      final replyingTo = _replyingTo;
      if (replyingTo != null &&
          replyingTo.userId != auth.user!.id &&
          replyingTo.userId != widget.post.userId) {
        await notifProv.createNotification(
          toUserId: replyingTo.userId,
          fromUserId: auth.user!.id,
          type: NotificationType.comment,
          postId: widget.post.id,
        );
      }

      _commentCtrl.clear();
      setState(() {
        _isAnonymous = false;
        _replyingTo = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  Future<void> _toggleTranslate(CommentModel comment) async {
    if (_translatedTextByCommentId.containsKey(comment.id)) {
      setState(() {
        if (_showOriginalCommentIds.contains(comment.id)) {
          _showOriginalCommentIds.remove(comment.id);
        } else {
          _showOriginalCommentIds.add(comment.id);
        }
      });
      return;
    }

    if (_translatingCommentIds.contains(comment.id)) {
      return;
    }

    final localeCode = Localizations.localeOf(context).languageCode;
    setState(() => _translatingCommentIds.add(comment.id));

    try {
      final result = await _translationService.translate(
        text: comment.text,
        targetLanguage: localeCode,
      );

      if (!mounted) {
        return;
      }

      if (result == null ||
          result.translatedText.trim().toLowerCase() ==
              comment.text.trim().toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment is already in your language.')),
        );
        return;
      }

      setState(() {
        _translatedTextByCommentId[comment.id] = result.translatedText;
        _showOriginalCommentIds.remove(comment.id);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _translatingCommentIds.remove(comment.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = context.watch<CommentProvider>().getCommentsForPost(widget.post.id);

    final commentsById = <String, CommentModel>{
      for (final comment in comments) comment.id: comment,
    };

    String? rootParentIdFor(CommentModel comment) {
      final initialParentId = comment.parentCommentId;
      if (initialParentId == null || initialParentId.isEmpty) {
        return null;
      }

      var currentParentId = initialParentId;
      while (true) {
        final parent = commentsById[currentParentId];
        if (parent == null) {
          return initialParentId;
        }

        final nextParentId = parent.parentCommentId;
        if (nextParentId == null || nextParentId.isEmpty) {
          return parent.id;
        }

        currentParentId = nextParentId;
      }
    }

    final topLevelComments = <CommentModel>[];
    final repliesByParent = <String, List<CommentModel>>{};

    for (final comment in comments) {
      final rootParentId = rootParentIdFor(comment);
      if (rootParentId == null) {
        topLevelComments.add(comment);
      } else {
        repliesByParent.putIfAbsent(rootParentId, () => <CommentModel>[]).add(comment);
      }
    }

    topLevelComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final replies in repliesByParent.values) {
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.softPink, height: 1),

          // Comments list
          Expanded(
            child: comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 12),
                      Text('No comments yet', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      const Text('Be the first to comment!', style: TextStyle(color: AppColors.textMed, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: topLevelComments.length,
                  itemBuilder: (_, i) {
                    final comment = topLevelComments[i];
                    final replies = repliesByParent[comment.id] ?? <CommentModel>[];
                    final isExpanded = _expandedReplyThreads.contains(comment.id);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentTile(
                          comment: comment,
                          onReply: () => _startReply(
                            comment,
                            _safeReplyUsername(comment),
                          ),
                          translatedText:
                              _translatedTextByCommentId[comment.id],
                          showOriginal:
                              _showOriginalCommentIds.contains(comment.id),
                          isTranslating:
                              _translatingCommentIds.contains(comment.id),
                          onTranslate: () => _toggleTranslate(comment),
                        ),
                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 56),
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedReplyThreads.remove(comment.id);
                                  } else {
                                    _expandedReplyThreads.add(comment.id);
                                  }
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_right_rounded,
                                size: 16,
                                color: AppColors.textMed,
                              ),
                              label: Text(
                                isExpanded
                                    ? 'Hide replies (${replies.length})'
                                    : 'View replies (${replies.length})',
                                style: const TextStyle(
                                  color: AppColors.textMed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (replies.isNotEmpty && isExpanded)
                          ...replies.map(
                            (reply) => _CommentTile(
                              comment: reply,
                              onReply: () => _startReply(
                                reply,
                                _safeReplyUsername(reply),
                              ),
                              translatedText:
                                  _translatedTextByCommentId[reply.id],
                              showOriginal:
                                  _showOriginalCommentIds.contains(reply.id),
                              isTranslating:
                                  _translatingCommentIds.contains(reply.id),
                              onTranslate: () => _toggleTranslate(reply),
                            ),
                          ),
                      ],
                    );
                  },
                ),
          ),

          // Input area
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.softPink, width: 1)),
              color: AppColors.white,
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _replyingLabel(_replyingTo!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _replyingTo = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Anonymous toggle (if post allows)
                if (widget.post.isAnonymous)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isAnonymous,
                          onChanged: (v) => setState(() => _isAnonymous = v ?? false),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          activeColor: AppColors.deepPink,
                        ),
                        const Text('Comment anonymously', style: TextStyle(fontSize: 13, color: AppColors.textDark)),
                      ],
                    ),
                  ),

                // Input field + submit
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: AppColors.textLight),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.softPink),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isPosting ? null : _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.deepPink,
                        ),
                        child: _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single comment tile
class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback? onReply;
  final String? translatedText;
  final bool showOriginal;
  final bool isTranslating;
  final VoidCallback? onTranslate;

  const _CommentTile({
    required this.comment,
    this.onReply,
    this.translatedText,
    this.showOriginal = false,
    this.isTranslating = false,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userProv = context.watch<UserProvider>();
    final commentProv = context.watch<CommentProvider>();
    
    final user = userProv.getUserById(comment.userId);
    final isLiked = comment.likedByIds.contains(auth.user?.id ?? '');
    final avatarImage = comment.isAnonymous ? null : _resolveAvatarImage(user?.avatarUrl);
    final isReply =
        comment.parentCommentId != null && comment.parentCommentId!.isNotEmpty;
    final hasTranslation = translatedText != null && translatedText!.trim().isNotEmpty;
    final bodyText = hasTranslation && !showOriginal ? translatedText! : comment.text;
    final translateLabel = isTranslating
      ? 'Translating...'
      : hasTranslation
        ? (showOriginal ? 'Show translated' : 'Show original')
        : 'Translate';

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 36 : 16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: comment.isAnonymous
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherUserProfileScreen(userId: comment.userId),
                        ),
                      );
                    },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.lavenderLight,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            comment.isAnonymous ? SoftSymbols.blossom : (user?.displayName.substring(0, 1).toUpperCase() ?? '?'),
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.isAnonymous ? SoftSymbols.anonymous : (user?.displayName ?? 'Unknown'),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(comment.createdAt),
                              style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bodyText,
                          style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                        ),
                        if (hasTranslation && !showOriginal)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Translated',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            if (isLiked) {
                              commentProv.unlikeComment(comment.postId, comment.id, auth.user?.id ?? '');
                            } else {
                              commentProv.likeComment(comment.postId, comment.id, auth.user?.id ?? '');
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 14,
                                color: isLiked ? AppColors.deepPink : AppColors.textLight,
                              ),
                              const SizedBox(width: 4),
                              if (comment.likedByIds.isNotEmpty)
                                Text(
                                  '${comment.likedByIds.length}',
                                  style: const TextStyle(color: AppColors.textMed, fontSize: 11),
                                ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: onReply,
                                child: const Text(
                                  'Reply',
                                  style: TextStyle(
                                    color: AppColors.textMed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: onTranslate,
                                child: Text(
                                  translateLabel,
                                  style: TextStyle(
                                    color: isTranslating
                                        ? AppColors.textLight
                                        : AppColors.lavenderDeep,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete button (if own comment)
          if (auth.user?.id == comment.userId)
            GestureDetector(
              onTap: () async {
                await commentProv.deleteComment(comment.postId, comment.id);
                await context.read<PostProvider>().reloadFeed(reset: true);
              },
              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textLight),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
