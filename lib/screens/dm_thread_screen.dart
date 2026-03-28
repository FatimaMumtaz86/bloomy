import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../navigation/app_router.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../widgets/app_image.dart';

class DmThreadScreen extends StatefulWidget {
  final String chatId;

  const DmThreadScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends State<DmThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _threadUser;
  String? _threadUserId;
  bool _isLoadingThreadUser = false;
  bool _didTryChatDocLookup = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onThreadScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      await chatProvider.init(currentUserId);
      await chatProvider.openChat(widget.chatId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onThreadScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onThreadScroll() async {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.pixels > 140) {
      return;
    }

    await context.read<ChatProvider>().loadOlderMessages(widget.chatId);
  }

  ChatModel? _findChat(ChatProvider chatProvider) {
    for (final chat in chatProvider.chats) {
      if (chat.id == widget.chatId) {
        return chat;
      }
    }
    return null;
  }

  String? _findOtherUserIdFromMessages({
    required List<ChatMessageModel> messages,
    required String currentUserId,
  }) {
    for (final message in messages.reversed) {
      final senderId = message.senderId.trim();
      if (senderId.isNotEmpty && senderId != currentUserId) {
        return senderId;
      }
    }
    return null;
  }

  Future<void> _ensureThreadUserFromChatDoc({
    required String currentUserId,
    required UserProvider userProvider,
  }) async {
    if (_didTryChatDocLookup) {
      return;
    }
    _didTryChatDocLookup = true;

    try {
      final chat = await _firestoreService.getChatById(widget.chatId);
      if (chat == null) {
        return;
      }

      String? otherUserId;
      for (final participantId in chat.participantIds) {
        if (participantId != currentUserId) {
          otherUserId = participantId;
          break;
        }
      }

      if (otherUserId == null || otherUserId.isEmpty) {
        return;
      }

      await _ensureThreadUser(
        otherUserId: otherUserId,
        userProvider: userProvider,
      );
    } catch (_) {
      // Keep thread usable even when chat doc lookup fails.
    }
  }

  Future<void> _ensureThreadUser({
    required String? otherUserId,
    required UserProvider userProvider,
  }) async {
    if (otherUserId == null || otherUserId.isEmpty) {
      return;
    }

    final fromCache = userProvider.getUserById(otherUserId);
    if (fromCache != null) {
      if (_threadUserId == otherUserId && _threadUser == fromCache) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _threadUser = fromCache;
        _threadUserId = otherUserId;
      });
      return;
    }

    if (_threadUserId == otherUserId && _threadUser != null) {
      return;
    }

    if (_isLoadingThreadUser && _threadUserId == otherUserId) {
      return;
    }

    _threadUserId = otherUserId;
    _isLoadingThreadUser = true;

    try {
      final fetched = await _firestoreService.getUser(otherUserId);
      if (!mounted || _threadUserId != otherUserId || fetched == null) {
        return;
      }
      setState(() {
        _threadUser = fetched;
      });
    } finally {
      if (mounted && _threadUserId == otherUserId) {
        setState(() {
          _isLoadingThreadUser = false;
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    try {
      await context.read<ChatProvider>().sendText(
            chatId: widget.chatId,
            text: text,
          );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
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
          title: const Text('Chat'),
          backgroundColor: AppColors.cream,
        ),
        body: const Center(child: Text('Sign in to access chat.')),
      );
    }

    final chat = _findChat(chatProvider);
    final messages = chatProvider.messagesForChat(widget.chatId);

    String? otherUserId =
        chat == null ? null : chatProvider.otherParticipantId(chat);
    otherUserId ??= _findOtherUserIdFromMessages(
      messages: messages,
      currentUserId: currentUser.id,
    );
    otherUserId ??= _threadUserId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureThreadUser(
        otherUserId: otherUserId,
        userProvider: userProvider,
      );

      if (otherUserId == null || otherUserId.isEmpty) {
        _ensureThreadUserFromChatDoc(
          currentUserId: currentUser.id,
          userProvider: userProvider,
        );
      }
    });

    final otherUser = otherUserId == null
        ? _threadUser
        : (userProvider.getUserById(otherUserId) ??
            (_threadUserId == otherUserId ? _threadUser : null));
    final profileUserId = otherUserId;

    final title = otherUser?.displayName.isNotEmpty == true
        ? otherUser!.displayName
        : (otherUser?.username ??
            (_isLoadingThreadUser ? 'Loading profile' : 'Direct message'));
    final otherAvatar = resolveAvatarImage(otherUser?.avatarUrl);

    final hasMoreMessages = chatProvider.hasMoreMessages(widget.chatId);
    final isLoadingOlder = chatProvider.isLoadingOlderMessages(widget.chatId);

    if (chat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<ChatProvider>().markChatRead(
              chat.id,
              at: chat.lastMessageAt,
            );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: (profileUserId == null || profileUserId.isEmpty)
              ? null
              : () => Navigator.pushNamed(
                    context,
                    AppRoutes.profile(profileUserId),
                  ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.lavenderLight,
                backgroundImage: otherAvatar,
                child: otherAvatar == null
                    ? Text(
                        title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.deepPink,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.cream,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hi to start the conversation.',
                      style: TextStyle(color: AppColors.textMed),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        if (isLoadingOlder) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.deepPink,
                              ),
                            ),
                          );
                        }

                        if (!hasMoreMessages) {
                          return const SizedBox.shrink();
                        }

                        return Center(
                          child: TextButton(
                            onPressed: () => context
                                .read<ChatProvider>()
                                .loadOlderMessages(widget.chatId),
                            child: const Text('Load older messages'),
                          ),
                        );
                      }

                      final message = messages[index - 1];
                      final isMine = message.senderId == currentUser.id;
                      final senderUser =
                          userProvider.getUserById(message.senderId);
                      final senderAvatar = resolveAvatarImage(senderUser?.avatarUrl);
                      final senderInitial = senderUser?.displayName.isNotEmpty == true
                          ? senderUser!.displayName.substring(0, 1).toUpperCase()
                          : (senderUser?.username.isNotEmpty == true
                              ? senderUser!.username.substring(0, 1).toUpperCase()
                              : '?');
                      return _MessageBubble(
                        message: message,
                        isMine: isMine,
                        senderAvatar: senderAvatar,
                        senderInitial: senderInitial,
                        timeLabel: _formatTime(message.createdAt),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.deepPink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  final ImageProvider<Object>? senderAvatar;
  final String senderInitial;
  final String timeLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderAvatar,
    required this.senderInitial,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.deepPink : AppColors.white;
    final textColor = isMine ? Colors.white : AppColors.textDark;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isMine
            ? null
            : [
                BoxShadow(
                  color: AppColors.lavender.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.isText)
            Text(
              message.text ?? '',
              style: TextStyle(color: textColor),
            ),
          if (message.isSharedPost)
            _SharedPostMessage(
              message: message,
              isMine: isMine,
            ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(
              color: isMine
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppColors.textLight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.lavenderLight,
          backgroundImage: senderAvatar,
          child: senderAvatar == null
              ? Text(
                  senderInitial,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.deepPink,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

class _SharedPostMessage extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;

  const _SharedPostMessage({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isMine
        ? Colors.white.withValues(alpha: 0.2)
        : AppColors.cream;
    final textColor = isMine ? Colors.white : AppColors.textDark;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shared a post',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message.sharedPostImageUrl != null &&
              message.sharedPostImageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  imageUrl: message.sharedPostImageUrl,
                  width: 190,
                  height: 130,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (message.sharedPostCaption != null &&
              message.sharedPostCaption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message.sharedPostCaption!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor),
              ),
            ),
          if (message.sharedPostId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.post(message.sharedPostId!),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: isMine ? Colors.white : AppColors.deepPink,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View post'),
              ),
            ),
        ],
      ),
    );
  }
}
