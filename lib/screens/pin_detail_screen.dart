import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../widgets/app_image.dart';
import '../widgets/save_pin_collection_sheet.dart';
import 'profile_screen.dart';

class PinDetailByIdScreen extends StatefulWidget {
  final String pinId;

  const PinDetailByIdScreen({required this.pinId, super.key});

  @override
  State<PinDetailByIdScreen> createState() => _PinDetailByIdScreenState();
}

class _PinDetailByIdScreenState extends State<PinDetailByIdScreen> {
  late Future<PinModel?> _pinFuture;

  @override
  void initState() {
    super.initState();
    _pinFuture = context.read<PinProvider>().fetchPinById(widget.pinId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PinModel?>(
      future: _pinFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(backgroundColor: AppColors.cream, elevation: 0),
            body: const Center(
              child: Text(
                'Pin not found',
                style: TextStyle(color: AppColors.textDark),
              ),
            ),
          );
        }

        return PinDetailScreen(pin: snapshot.data!);
      },
    );
  }
}

class PinDetailScreen extends StatefulWidget {
  final PinModel pin;
  const PinDetailScreen({required this.pin, super.key});

  @override
  State<PinDetailScreen> createState() => _PinDetailScreenState();
}

class _PinDetailScreenState extends State<PinDetailScreen> {
  static const double _pinMediaAspectRatio = 4 / 5;

  late PinModel _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.pin;
  }

  Future<void> _refreshPin() async {
    final latest = await context.read<PinProvider>().fetchPinById(_pin.id);
    if (!mounted || latest == null) {
      return;
    }
    setState(() => _pin = latest);
  }

  Future<void> _deletePin() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete pin?'),
        content: const Text('This pin will be removed permanently.'),
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
      await context.read<PinProvider>().deletePin(_pin.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin deleted.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete pin: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final pinProvider = context.read<PinProvider>();
    final currentUserId = auth.user?.id ?? '';
    final isLiked =
        currentUserId.isNotEmpty && _pin.likedByIds.contains(currentUserId);
    final isSaved =
        currentUserId.isNotEmpty && _pin.savedByIds.contains(currentUserId);
    final isOwnPin = currentUserId.isNotEmpty && _pin.userId == currentUserId;
    final pinUser = userProvider.getUserById(_pin.userId);
    final authorName = pinUser?.displayName ?? _pin.username ?? 'Unknown';
    final authorUsername = pinUser?.username ?? _pin.username ?? _pin.userId;
    final avatarImage = resolveAvatarImage(pinUser?.avatarUrl);
    final authorInitial =
        authorName.isNotEmpty ? authorName.substring(0, 1).toUpperCase() : '?';
    final mediaLayout = context.watch<MediaLayoutProvider>();
    final useContainOnWeb = kIsWeb && mediaLayout.useContainOnWeb;
    final mediaFit = useContainOnWeb ? BoxFit.contain : BoxFit.cover;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        actions: [
          if (isOwnPin)
            IconButton(
              onPressed: _deletePin,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.deepPink),
              tooltip: 'Delete pin',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pin.imageUrl != null && _pin.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: AppColors.cream,
                    child: AspectRatio(
                      aspectRatio: _pinMediaAspectRatio,
                      child: AppImage(
                        imageUrl: _pin.imageUrl,
                        width: double.infinity,
                        fit: mediaFit,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(_pin.title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OtherUserProfileScreen(userId: _pin.userId),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.lavenderLight,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              authorInitial,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.deepPink,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@$authorUsername',
                          style: const TextStyle(
                              color: AppColors.textMed, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_pin.description != null && _pin.description!.isNotEmpty)
                Text(_pin.description!,
                    style: const TextStyle(
                        color: AppColors.textMed, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: currentUserId.isEmpty
                        ? null
                        : () async {
                            if (isLiked) {
                              await pinProvider.unlikePin(
                                  _pin.id, currentUserId);
                            } else {
                              await pinProvider.likePin(_pin.id, currentUserId);
                            }
                            await _refreshPin();
                          },
                    icon: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: AppColors.deepPink,
                      size: 22,
                    ),
                  ),
                  Text('${_pin.likedByIds.length}',
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: currentUserId.isEmpty
                        ? null
                        : () async {
                            await showSavePinCollectionSheet(
                              context: context,
                              pinId: _pin.id,
                              userId: currentUserId,
                              wasSaved: isSaved,
                            );
                            await _refreshPin();
                          },
                    icon: Icon(isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline),
                    label: Text(isSaved ? 'Saved' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
