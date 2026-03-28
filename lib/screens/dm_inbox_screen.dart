import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../navigation/app_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';

class DmInboxScreen extends StatefulWidget {
  const DmInboxScreen({super.key});

  @override
  State<DmInboxScreen> createState() => _DmInboxScreenState();
}

class _DmInboxScreenState extends State<DmInboxScreen> {
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

  bool _matchesUser(UserModel user) {
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

  Future<void> _openChatById(String chatId) async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.openChat(chatId);

    if (!mounted) {
      return;
    }

    Navigator.pushNamed(context, AppRoutes.chat(chatId));
  }

  void _openSharedPostPreview(String postId) {
    Navigator.pushNamed(context, AppRoutes.post(postId));
  }

  Future<void> _startChatWithUser(
    UserModel currentUser,
    UserModel targetUser,
    ChatModel? existingChat,
  ) async {
    final chatProvider = context.read<ChatProvider>();

    if (existingChat != null) {
      await _openChatById(existingChat.id);
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
      await _openChatById(chatId);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUser = auth.user;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: AppColors.cream,
        ),
        body: const Center(child: Text('Sign in to access messages.')),
      );
    }

    final chatByOtherUserId = <String, ChatModel>{};
    for (final chat in chatProvider.chats) {
      final otherUserId = chatProvider.otherParticipantId(chat);
      if (otherUserId != null && otherUserId.isNotEmpty) {
        chatByOtherUserId[otherUserId] = chat;
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

      return _matchesUser(otherUser);
    }).toList();

    final users = userProvider.users
        .where((candidate) => candidate.id != currentUser.id)
        .where(_matchesUser)
        .toList()
      ..sort((a, b) {
        if (a.isPublic == b.isPublic) {
          return a.username.compareTo(b.username);
        }
        return a.isPublic ? -1 : 1;
      });

    final usersToShow = _query.isNotEmpty ? users : users.take(20).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.cream,
        actions: [
          if (chatProvider.unreadCount > 0)
            TextButton(
              onPressed: () => context.read<ChatProvider>().markAllAsRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats or users',
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
                fillColor: AppColors.white,
              ),
            ),
          ),
          Expanded(
            child: chatProvider.isLoadingInbox && chatProvider.chats.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.deepPink),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      if (filteredChats.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Inbox',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMed,
                            ),
                          ),
                        ),
                      ...filteredChats.map((chat) {
                        final otherUserId = chatProvider.otherParticipantId(chat);
                        final otherUser = otherUserId == null
                            ? null
                            : userProvider.getUserById(otherUserId);
                        final isUnread = chatProvider.isChatUnreadById(chat.id);

                        final displayName =
                            otherUser?.displayName.isNotEmpty == true
                                ? otherUser!.displayName
                                : (otherUser?.username ?? 'Unknown user');
                        final handle = otherUser?.username ?? 'unknown';

                        return Card(
                          color: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            onTap: () => _openChatById(chat.id),
                            tileColor:
                                isUnread ? AppColors.softPink.withValues(alpha: 0.18) : null,
                            leading: otherUser == null
                                ? CircleAvatar(
                                    backgroundColor: AppColors.lavenderLight,
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName.substring(0, 1).toUpperCase()
                                          : '?',
                                    ),
                                  )
                                : _buildUserAvatar(
                                    otherUser,
                                    backgroundColor: AppColors.lavenderLight,
                                  ),
                            title: Text(displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@$handle · ${chat.lastMessageText}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (chat.lastMessageType == ChatMessageType.sharedPost &&
                                    chat.lastSharedPostId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _openSharedPostPreview(chat.lastSharedPostId!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.lavenderLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Open shared post preview',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.lavenderDeep,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _timeAgo(chat.lastMessageAt),
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (usersToShow.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            'People',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMed,
                            ),
                          ),
                        ),
                      ...usersToShow.map((user) {
                        final existingChat = chatByOtherUserId[user.id];
                        final canMessage = existingChat != null ||
                            chatProvider.canMessageUser(
                              currentUserId: currentUser.id,
                              targetUser: user,
                            );

                        return Card(
                          color: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            onTap: () => _startChatWithUser(
                              currentUser,
                              user,
                              existingChat,
                            ),
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
                              canMessage
                                  ? Icons.chat_bubble_outline_rounded
                                  : Icons.lock_outline,
                              color: canMessage
                                  ? AppColors.deepPink
                                  : AppColors.textLight,
                            ),
                          ),
                        );
                      }),
                      if (filteredChats.isEmpty && usersToShow.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
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
    );
  }
}
