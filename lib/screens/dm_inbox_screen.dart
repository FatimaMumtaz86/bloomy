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

  bool _matchesGroupChat(ChatModel chat, UserProvider userProvider) {
    if (_query.isEmpty) {
      return true;
    }

    final names = chat.participantIds
        .map((id) => userProvider.getUserById(id)?.displayName ?? '')
        .join(' ')
        .toLowerCase();
    final groupName = (chat.groupName ?? '').toLowerCase();
    final message = chat.lastMessageText.toLowerCase();
    return '$groupName $names $message'.contains(_query);
  }

  Future<void> _showCreateGroupSheet(UserModel currentUser) async {
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();
    final groupNameController = TextEditingController();
    final searchController = TextEditingController();
    final selectedUserIds = <String>{};
    var search = '';
    var isCreating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final users = userProvider.users
                .where((user) => user.id != currentUser.id)
                .where((user) {
                  if (search.isEmpty) {
                    return true;
                  }
                  final text =
                      '${user.displayName} ${user.username}'.toLowerCase();
                  return text.contains(search);
                })
                .toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName));

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
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
                        'Create group',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        hintText: 'Group name',
                        prefixIcon: Icon(Icons.groups_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setModalState(() => search = value.trim().toLowerCase());
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: users.isEmpty
                          ? const Center(
                              child: Text(
                                'No users found',
                                style: TextStyle(color: AppColors.textMed),
                              ),
                            )
                          : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (_, index) {
                                final user = users[index];
                                final isSelected =
                                    selectedUserIds.contains(user.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setModalState(() {
                                      if (checked == true) {
                                        selectedUserIds.add(user.id);
                                      } else {
                                        selectedUserIds.remove(user.id);
                                      }
                                    });
                                  },
                                  title: Text(user.displayName),
                                  subtitle: Text('@${user.username}'),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isCreating
                            ? null
                            : () async {
                                final groupName =
                                    groupNameController.text.trim();
                                if (groupName.isEmpty) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Enter a group name.'),
                                    ),
                                  );
                                  return;
                                }

                                if (selectedUserIds.length < 2) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Select at least 2 people for a group.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isCreating = true);
                                try {
                                  final chatId = await chatProvider.createGroupChat(
                                    groupName: groupName,
                                    selectedUserIds: selectedUserIds.toList(),
                                  );
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  Navigator.pop(sheetContext);
                                  await _openChatById(chatId);
                                } catch (e) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Could not create group: $e'),
                                    ),
                                  );
                                } finally {
                                  if (sheetContext.mounted) {
                                    setModalState(() => isCreating = false);
                                  }
                                }
                              },
                        icon: isCreating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.group_add_outlined),
                        label: Text(
                          isCreating ? 'Creating group...' : 'Create group',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    groupNameController.dispose();
    searchController.dispose();
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
    for (final chat in chatProvider.chats.where((chat) => !chatProvider.isGroupChat(chat))) {
      final otherUserId = chatProvider.otherParticipantId(chat);
      if (otherUserId != null && otherUserId.isNotEmpty) {
        chatByOtherUserId[otherUserId] = chat;
      }
    }

    final filteredDirectChats =
        chatProvider.chats.where((chat) => !chatProvider.isGroupChat(chat)).where((chat) {
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

    final filteredGroupChats =
        chatProvider.chats.where(chatProvider.isGroupChat).where((chat) {
      return _matchesGroupChat(chat, userProvider);
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
          IconButton(
            icon: const Icon(Icons.group_add_outlined, color: AppColors.textDark),
            tooltip: 'Create group',
            onPressed: () => _showCreateGroupSheet(currentUser),
          ),
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
                      if (filteredGroupChats.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Groups',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMed,
                            ),
                          ),
                        ),
                      ...filteredGroupChats.map((chat) {
                        final memberCount = chat.participantIds.length;
                        final isUnread = chatProvider.isChatUnreadById(chat.id);
                        final groupTitle =
                            (chat.groupName ?? '').trim().isNotEmpty
                                ? chat.groupName!.trim()
                                : 'Group chat';

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
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.lavenderLight,
                              child: Icon(Icons.groups_2_rounded,
                                  color: AppColors.deepPink),
                            ),
                            title: Text(groupTitle),
                            subtitle: Text(
                              '$memberCount members · ${chat.lastMessageText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      if (filteredDirectChats.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            'Direct messages',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMed,
                            ),
                          ),
                        ),
                      ...filteredDirectChats.map((chat) {
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
                      if (filteredGroupChats.isEmpty &&
                          filteredDirectChats.isEmpty &&
                          usersToShow.isEmpty)
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
