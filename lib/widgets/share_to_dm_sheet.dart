import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';

class ShareToDmSheet extends StatefulWidget {
  final PostModel post;

  const ShareToDmSheet({
    super.key,
    required this.post,
  });

  @override
  State<ShareToDmSheet> createState() => _ShareToDmSheetState();
}

class _ShareToDmSheetState extends State<ShareToDmSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      await context.read<ChatProvider>().init(currentUserId);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  bool _matches(UserModel user) {
    if (_query.isEmpty) {
      return true;
    }

    final haystack =
        '${user.displayName} ${user.username} ${user.bio ?? ''}'.toLowerCase();
    return haystack.contains(_query);
  }

  Widget _buildUserAvatar(
    UserModel user, {
    required Color backgroundColor,
  }) {
    final avatarImage = resolveAvatarImage(user.avatarUrl);
    final initial = user.displayName.isNotEmpty
        ? user.displayName.substring(0, 1).toUpperCase()
        : (user.username.isNotEmpty ? user.username.substring(0, 1).toUpperCase() : '?');

    return CircleAvatar(
      backgroundColor: backgroundColor,
      backgroundImage: avatarImage,
      child: avatarImage == null ? Text(initial) : null,
    );
  }

  Future<void> _shareToChat(String chatId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.openChat(chatId);
      await chatProvider.sharePost(chatId: chatId, post: widget.post);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Post shared in chat.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to share post: $e')),
      );
    }
  }

  Future<void> _shareToUser(
    UserModel currentUser,
    UserModel targetUser,
    ChatModel? existingChat,
  ) async {
    final chatProvider = context.read<ChatProvider>();
    if (existingChat != null) {
      await _shareToChat(existingChat.id);
      return;
    }

    final canMessage = chatProvider.canMessageUser(
      currentUserId: currentUser.id,
      targetUser: targetUser,
    );
    if (!canMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow this private profile first to message.'),
        ),
      );
      return;
    }

    try {
      final chatId = await chatProvider.ensureDirectChat(targetUser.id);
      await _shareToChat(chatId);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final currentUser = auth.user;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final chatsByOtherUser = <String, ChatModel>{};
    for (final chat in chatProvider.chats) {
      final otherUserId = chatProvider.otherParticipantId(chat);
      if (otherUserId != null && otherUserId.isNotEmpty) {
        chatsByOtherUser[otherUserId] = chat;
      }
    }

    final filteredChats = chatProvider.chats.where((chat) {
      final otherUserId = chatProvider.otherParticipantId(chat);
      if (otherUserId == null || otherUserId.isEmpty) {
        return false;
      }

      final otherUser = userProvider.getUserById(otherUserId);
      if (otherUser == null) {
        return _query.isEmpty;
      }

      return _matches(otherUser);
    }).toList();

    final allUsers = userProvider.users
        .where((user) => user.id != currentUser.id)
        .where(_matches)
        .toList();

    allUsers.sort((a, b) {
      if (a.isPublic == b.isPublic) {
        return a.username.compareTo(b.username);
      }
      return a.isPublic ? -1 : 1;
    });

    final showUsers = _query.isNotEmpty ? allUsers : allUsers.take(20).toList();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Share to message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or username',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.cream,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (filteredChats.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Recent chats',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMed,
                        ),
                      ),
                    ),
                  ...filteredChats.map((chat) {
                    final otherUserId = chatProvider.otherParticipantId(chat);
                    final otherUser =
                        otherUserId == null ? null : userProvider.getUserById(otherUserId);
                    if (otherUser == null) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildUserAvatar(
                        otherUser,
                        backgroundColor: AppColors.lavenderLight,
                      ),
                      title: Text(otherUser.displayName),
                      subtitle: Text(
                        chat.lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.send_rounded,
                          color: AppColors.deepPink),
                      onTap: () => _shareToChat(chat.id),
                    );
                  }),
                  if (showUsers.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        'People',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMed,
                        ),
                      ),
                    ),
                  ...showUsers.map((user) {
                    final existingChat = chatsByOtherUser[user.id];
                    final canMessage = existingChat != null ||
                        chatProvider.canMessageUser(
                          currentUserId: currentUser.id,
                          targetUser: user,
                        );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildUserAvatar(
                        user,
                        backgroundColor: AppColors.softPink,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(
                        canMessage
                            ? '@${user.username}'
                            : '@${user.username} · private profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        canMessage ? Icons.chat_bubble_outline_rounded : Icons.lock_outline,
                        color: canMessage ? AppColors.deepPink : AppColors.textLight,
                      ),
                      onTap: () => _shareToUser(
                        currentUser,
                        user,
                        existingChat,
                      ),
                    );
                  }),
                  if (filteredChats.isEmpty && showUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No chats or users found.',
                          style: TextStyle(color: AppColors.textMed),
                        ),
                      ),
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
