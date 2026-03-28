import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';

/// Notifications screen showing likes, follows, comments, and follow requests
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<UserProvider>().refresh();
        context.read<NotificationProvider>().loadNotifications(auth.user!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>().notifications;

    // Sort by recency
    final sorted = [...notifications];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text('Notifications',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                for (var notif in notifications.where((n) => !n.isRead)) {
                  context.read<NotificationProvider>().markAsRead(notif.id);
                }
              },
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: AppColors.deepPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'When someone likes, comments, or follows you, it will show up here',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMed, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _NotificationTile(notification: sorted[i]),
            ),
    );
  }
}

/// Single notification tile
class _NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final followProv = context.read<FollowProvider>();
    final notifProv = context.read<NotificationProvider>();
    final auth = context.read<AuthProvider>();

    final fromUser = userProv.getUserById(widget.notification.fromUserId);
    final displayName = fromUser?.displayName ?? 'Someone';
    final username = fromUser?.username ?? widget.notification.fromUserId;
    final avatarImage = resolveAvatarImage(fromUser?.avatarUrl);
    final avatarInitial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    final backgroundColor =
        widget.notification.isRead ? AppColors.cream : AppColors.white;

    return Container(
      color: backgroundColor,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: () async {
            await notifProv.markAsRead(widget.notification.id);
            if (!context.mounted) {
              return;
            }

            if (widget.notification.type == NotificationType.followRequest) {
              return;
            }

            if (widget.notification.postId != null &&
                widget.notification.postId!.isNotEmpty) {
              Navigator.pushNamed(
                context,
                AppRoutes.post(widget.notification.postId!),
              );
              return;
            }

            if (widget.notification.pinId != null &&
                widget.notification.pinId!.isNotEmpty) {
              Navigator.pushNamed(
                context,
                AppRoutes.pin(widget.notification.pinId!),
              );
              return;
            }

            if (widget.notification.type == NotificationType.follow ||
                widget.notification.type == NotificationType.followAccepted) {
              Navigator.pushNamed(
                context,
                AppRoutes.profile(widget.notification.fromUserId),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.profile(widget.notification.fromUserId),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.lavenderLight,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            avatarInitial,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepPink),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark),
                                  ),
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: _getNotificationText(
                                        widget.notification.type),
                                    style: const TextStyle(
                                        color: AppColors.textMed),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _timeAgo(widget.notification.createdAt),
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Follow request buttons
                if (widget.notification.type == NotificationType.followRequest)
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _isProcessing
                            ? null
                            : () async {
                                setState(() => _isProcessing = true);
                                try {
                                  final currentUserId = auth.user?.id;
                                  if (currentUserId == null) {
                                    return;
                                  }

                                  await followProv.acceptFollowRequest(
                                    userId: currentUserId,
                                    followerId: widget.notification.fromUserId,
                                  );

                                  // Create follow accepted notification
                                  await context
                                      .read<NotificationProvider>()
                                      .createNotification(
                                        toUserId:
                                            widget.notification.fromUserId,
                                        fromUserId: currentUserId,
                                        type: NotificationType.followAccepted,
                                      );

                                  // Remove this notification
                                  await notifProv.deleteNotification(
                                      widget.notification.id);
                                  await context.read<UserProvider>().refresh();
                                  await context
                                      .read<AuthProvider>()
                                      .refreshCurrentUser();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Followed.')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error: ${e.toString()}')),
                                    );
                                  }
                                } finally {
                                  if (mounted)
                                    setState(() => _isProcessing = false);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.deepPink,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _isProcessing
                            ? null
                            : () async {
                                setState(() => _isProcessing = true);
                                try {
                                  final currentUserId = auth.user?.id;
                                  if (currentUserId == null) {
                                    return;
                                  }

                                  await followProv.declineFollowRequest(
                                    userId: currentUserId,
                                    followerId: widget.notification.fromUserId,
                                  );
                                  await notifProv.deleteNotification(
                                      widget.notification.id);
                                  await context.read<UserProvider>().refresh();
                                  await context
                                      .read<AuthProvider>()
                                      .refreshCurrentUser();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Request declined')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error: ${e.toString()}')),
                                    );
                                  }
                                } finally {
                                  if (mounted)
                                    setState(() => _isProcessing = false);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.deepPink),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                                color: AppColors.deepPink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Notification badge (unread)
                if (!widget.notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.deepPink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNotificationText(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'liked your post';
      case NotificationType.comment:
        return 'commented on your post';
      case NotificationType.follow:
        return 'followed you';
      case NotificationType.followRequest:
        return 'sent you a follow request';
      case NotificationType.followAccepted:
        return 'accepted your follow request';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
