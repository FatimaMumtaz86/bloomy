import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import 'pin_detail_screen.dart' as pin_detail;
import '../theme/app_theme.dart';
import '../utils/soft_symbols.dart';
import '../utils/image_adjust_utils.dart';
import '../widgets/app_image.dart';
import '../widgets/edit_post_sheet.dart';
import '../widgets/save_post_collection_sheet.dart';

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

  if (kIsWeb) {
    return null;
  }

  final file = File(avatarUrl);
  if (!file.existsSync()) {
    return null;
  }
  return FileImage(file);
}

Widget _buildProfileAvatar({
  required String displayName,
  required String? avatarUrl,
  required double radius,
}) {
  final image = _resolveAvatarImage(avatarUrl);
  final initial =
      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.white,
    backgroundImage: image,
    child: image == null
        ? Text(
            initial,
            style: TextStyle(
              fontSize: radius * 0.8,
              color: AppColors.deepPink,
              fontWeight: FontWeight.w700,
            ),
          )
        : null,
  );
}

/// Main profile screen for current user
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _previewCurrentAvatar(UserModel user) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileAvatar(
                  displayName: user.displayName,
                  avatarUrl: user.avatarUrl,
                  radius: 62,
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmAvatarPreview(AdjustedImageSelection image) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final previewProvider = kIsWeb && image.uploadBytes != null
            ? MemoryImage(image.uploadBytes!)
            : FileImage(File(image.file.path));

        return AlertDialog(
          title: const Text('Use this profile photo?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundImage: previewProvider,
              ),
              const SizedBox(height: 10),
              const Text(
                'You can adjust again if needed.',
                style: TextStyle(color: AppColors.textMed),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Adjust again'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use photo'),
            ),
          ],
        );
      },
    );

    return accepted == true;
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final image = await pickAndAdjustImage(
        context: context,
        picker: _imagePicker,
        target: MediaAdjustTarget.avatar,
      );

      if (image == null || !mounted) {
        return;
      }

      final shouldUse = await _confirmAvatarPreview(image);
      if (!shouldUse || !mounted) {
        return;
      }

      final authProvider = context.read<AuthProvider>();
      await authProvider.updateProfile(
        avatarUrl: image.file.path,
        avatarBytes: image.uploadBytes,
        avatarFileName: image.fileName,
      );
      await context.read<UserProvider>().refresh();

      if (!mounted) {
        return;
      }

      if (authProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.error!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.updateProfile(avatarUrl: '');
    await context.read<UserProvider>().refresh();

    if (!mounted) {
      return;
    }

    if (authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo removed.')),
    );
  }

  Future<void> _showAvatarActions(UserModel user) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Preview profile photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _previewCurrentAvatar(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Upload and adjust photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('Remove profile photo'),
                textColor: Colors.red,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatar();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 320,
            backgroundColor: AppColors.cream,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 235) {
                    return const SizedBox.shrink();
                  }

                  return Container(
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showAvatarActions(user),
                                child: Stack(
                                  children: [
                                    _buildProfileAvatar(
                                      displayName: user.displayName,
                                      avatarUrl: user.avatarUrl,
                                      radius: 44,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                            color: AppColors.deepPink,
                                            shape: BoxShape.circle),
                                        child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark),
                                    ),
                                    Text(
                                      '@${user.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textMed,
                                          fontSize: 13),
                                    ),
                                    if (user.bio != null &&
                                        user.bio!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          user.bio!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.textMed,
                                              fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Stats
                          Row(
                            children: [
                              _StatChip(
                                count: context
                                    .watch<PostProvider>()
                                    .posts
                                    .where((p) =>
                                        p.userId == user.id && !p.isAnonymous)
                                    .length,
                                label: 'Posts',
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                count: context
                                    .watch<PinProvider>()
                                    .pins
                                    .where((p) => p.userId == user.id)
                                    .length,
                                label: 'Pins',
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                count: user.followerIds.length,
                                label: 'Followers',
                                onTap: () => _showConnectionsSheet(
                                  context,
                                  title: 'Followers',
                                  userIds: user.followerIds,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                count: user.followingIds.length,
                                label: 'Following',
                                onTap: () => _showConnectionsSheet(
                                  context,
                                  title: 'Following',
                                  userIds: user.followingIds,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textDark),
                onPressed: () => _showSettings(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              labelColor: AppColors.deepPink,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.deepPink,
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Pins & Boards'),
                Tab(text: 'My Space'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _UserPostsTab(userId: user.id),
            _UserPinsTab(userId: user.id),
            const _MySpaceTab(),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => const _SettingsModal(),
    );
  }

  void _showConnectionsSheet(
    BuildContext context, {
    required String title,
    required List<String> userIds,
  }) {
    final userProvider = context.read<UserProvider>();
    final followProvider = context.read<FollowProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final isFollowersSheet = title.toLowerCase() == 'followers';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SafeArea(
            top: false,
            child: userIds.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No users yet',
                        style: TextStyle(color: AppColors.textMed),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$title (${userIds.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(sheetContext).size.height * 0.55,
                        child: ListView.builder(
                          itemCount: userIds.length,
                          itemBuilder: (_, i) {
                            final id = userIds[i];
                            final listedUser = userProvider.getUserById(id);
                            final displayName =
                                listedUser?.displayName ?? 'User';
                            final username = listedUser?.username ?? id;
                            final avatarImage =
                                _resolveAvatarImage(listedUser?.avatarUrl);
                            final initial = displayName.isNotEmpty
                                ? displayName.substring(0, 1).toUpperCase()
                                : '?';
                            final canRemoveFollower = isFollowersSheet &&
                              currentUserId != null &&
                              currentUserId != id;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.lavenderLight,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Text(
                                        initial,
                                        style: const TextStyle(
                                            color: AppColors.deepPink),
                                      )
                                    : null,
                              ),
                              title: Text(displayName),
                              subtitle: Text('@$username'),
                              trailing: canRemoveFollower
                                  ? TextButton(
                                      onPressed: () async {
                                        try {
                                          await followProvider.removeFollower(
                                            userId: currentUserId,
                                            followerId: id,
                                          );
                                          await context
                                              .read<UserProvider>()
                                              .refresh();
                                          await context
                                              .read<AuthProvider>()
                                              .refreshCurrentUser();

                                          if (sheetContext.mounted) {
                                            ScaffoldMessenger.of(sheetContext)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Follower removed.'),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (sheetContext.mounted) {
                                            ScaffoldMessenger.of(sheetContext)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to remove follower: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: listedUser == null
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              OtherUserProfileScreen(
                                                  userId: listedUser.id),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// Posts Tab
class _UserPostsTab extends StatefulWidget {
  final String userId;
  const _UserPostsTab({required this.userId});

  @override
  State<_UserPostsTab> createState() => _UserPostsTabState();
}

class _UserPostsTabState extends State<_UserPostsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<PostProvider>().loadUserPosts(widget.userId, reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (_isLoadingMore || !_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels < threshold) {
      return;
    }

    final postProvider = context.read<PostProvider>();
    if (!postProvider.hasMoreUserPosts) {
      return;
    }

    _isLoadingMore = true;
    try {
      await postProvider.loadMoreUserPosts(widget.userId);
    } finally {
      _isLoadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final postProv = context.watch<PostProvider>();
    final userPosts = postProv.userPosts
        .where((p) => p.userId == widget.userId && !p.isAnonymous)
        .toList();
    userPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notes_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No posts yet',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: userPosts.length + (postProv.hasMoreUserPosts ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= userPosts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.deepPink),
            ),
          );
        }
        return _PostCard(post: userPosts[i]);
      },
    );
  }
}

// Pins & Boards Tab
class _UserPinsTab extends StatefulWidget {
  final String userId;
  const _UserPinsTab({required this.userId});

  @override
  State<_UserPinsTab> createState() => _UserPinsTabState();
}

class _UserPinsTabState extends State<_UserPinsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await context
          .read<PinProvider>()
          .loadUserPins(widget.userId, reset: true);
      await context.read<PinProvider>().loadUserBoards(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pinProv = context.watch<PinProvider>();
    final userPins =
        pinProv.userPins.where((p) => p.userId == widget.userId).toList();
    final userBoards =
        pinProv.boards.where((b) => b['userId'] == widget.userId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userBoards.isNotEmpty) ...[
            Text('Boards', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ...userBoards.map((board) {
              final boardId = board['id'] as String;
              final boardName = board['name'] as String;
              final pinCount =
                  userPins.where((p) => p.boardId == boardId).length;
              const colors = [
                AppColors.softPink,
                AppColors.lavender,
                AppColors.beige,
                AppColors.pink
              ];
              final idx = userBoards.indexOf(board);

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _BoardPinsList(boardId: boardId, boardName: boardName),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors[idx % colors.length],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(boardName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.textDark)),
                          Text('$pinCount pins',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMed)),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textLight),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (userPins.isNotEmpty) ...[
            if (userBoards.isNotEmpty) const SizedBox(height: 20),
            Text('Pins', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ...userPins.map((pin) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => pin_detail.PinDetailScreen(pin: pin)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.lavender.withOpacity(0.15),
                          blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    children: [
                      if (pin.imageUrl != null && pin.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AppImage(
                            imageUrl: pin.imageUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.lavenderLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                              child: Text(pin.title[0],
                                  style: const TextStyle(fontSize: 24))),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pin.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                            Text('${pin.likedByIds.length} likes',
                                style: const TextStyle(
                                    color: AppColors.textMed, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textLight),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (userPins.isEmpty && userBoards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 48,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text('No pins or boards yet',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Board pins list helper
class _BoardPinsList extends StatelessWidget {
  final String boardId;
  final String boardName;
  const _BoardPinsList({required this.boardId, required this.boardName});

  @override
  Widget build(BuildContext context) {
    final pinProv = context.watch<PinProvider>();
    final pins = pinProv.pins.where((p) => p.boardId == boardId).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(boardName,
            style: const TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: pins.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 12),
                  Text('No pins in this board',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pins.length,
              itemBuilder: (_, i) {
                final pin = pins[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => pin_detail.PinDetailScreen(pin: pin)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.lavender.withOpacity(0.15),
                            blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      children: [
                        if (pin.imageUrl != null && pin.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppImage(
                              imageUrl: pin.imageUrl,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pin.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                              if (pin.description != null) ...[
                                const SizedBox(height: 4),
                                Text(pin.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textMed,
                                        fontSize: 12)),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                  '${pin.likedByIds.length} likes • ${pin.savedByIds.length} saves',
                                  style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// My Space Tab with sub-tabs
class _MySpaceTab extends StatefulWidget {
  const _MySpaceTab();

  @override
  State<_MySpaceTab> createState() => _MySpaceTabState();
}

class _MySpaceTabState extends State<_MySpaceTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabs;

  @override
  void initState() {
    super.initState();
    _subTabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _subTabs,
          labelColor: AppColors.deepPink,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.deepPink,
          tabs: const [
            Tab(text: '${SoftSymbols.thread} Saved Posts'),
            Tab(text: '${SoftSymbols.heart} Liked Posts'),
            Tab(text: '${SoftSymbols.star} Saved Pins'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabs,
            children: const [
              _SavedPostsTab(),
              _LikedPostsTab(),
              _SavedPinsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// Centralized timing so expand/collapse feel can be tuned in one place.
const Duration _collectionExpandDuration = Duration(milliseconds: 320);
const Duration _collectionCollapseDuration = Duration(milliseconds: 240);
const Curve _collectionExpandCurve = Curves.easeOutCubic;
const Curve _collectionCollapseCurve = Curves.easeInCubic;

class _CollectionSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  const _CollectionSectionHeader({
    required this.title,
    required this.subtitle,
    this.isExpanded = false,
    this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softPink.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMed,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpen != null)
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textMed,
                    size: 18,
                  ),
                ),
              if (onTap != null)
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: _collectionExpandDuration,
                  curve: _collectionExpandCurve,
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.textMed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// Saved Posts sub-tab
class _SavedPostsTab extends StatefulWidget {
  const _SavedPostsTab();

  @override
  State<_SavedPostsTab> createState() => _SavedPostsTabState();
}

class _SavedPostsTabState extends State<_SavedPostsTab> {
  final Set<String> _expandedCollections = <String>{};

  @override
  Widget build(BuildContext context) {
    final savedProv = context.watch<SavedPostProvider>();
    final postProv = context.watch<PostProvider>();
    final savedPosts =
        postProv.posts.where((p) => savedProv.isSaved(p.id)).toList();
    savedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmark_border_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No saved posts yet',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    final postsByCollection = <String, List<PostModel>>{};
    for (final post in savedPosts) {
      final collection = savedProv.collectionFor(post.id);
      postsByCollection.putIfAbsent(collection, () => <PostModel>[]).add(post);
    }

    final collectionKeys = postsByCollection.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ...collectionKeys.map((key) {
          final posts = postsByCollection[key]!;
          final isExpanded = _expandedCollections.contains(key);
          final title = '${SoftSymbols.thread} $key';
          final subtitle = '${posts.length} saved posts';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CollectionSectionHeader(
                title: title,
                subtitle: subtitle,
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCollections.remove(key);
                    } else {
                      _expandedCollections.add(key);
                    }
                  });
                },
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SavedPostCollectionScreen(
                        collectionName: key,
                        posts: posts,
                      ),
                    ),
                  );
                },
              ),
              AnimatedSwitcher(
                duration: _collectionExpandDuration,
                reverseDuration: _collectionCollapseDuration,
                switchInCurve: _collectionExpandCurve,
                switchOutCurve: _collectionCollapseCurve,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: isExpanded
                    ? Column(
                        key: ValueKey<String>('posts-expanded-$key'),
                        children: posts.map((post) => _PostCard(post: post)).toList(),
                      )
                    : const SizedBox(
                        key: ValueKey<String>('posts-collapsed'),
                      ),
              ),
              const SizedBox(height: 6),
            ],
          );
        }),
      ],
    );
  }
}

// Liked Posts sub-tab
class _LikedPostsTab extends StatelessWidget {
  const _LikedPostsTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final postProv = context.watch<PostProvider>();
    final likedPosts = postProv.posts
        .where((p) => p.likedByIds.contains(auth.user?.id ?? ''))
        .toList();
    likedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (likedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No liked posts yet',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: likedPosts.length,
      itemBuilder: (_, i) => _PostCard(post: likedPosts[i]),
    );
  }
}

// Saved Pins sub-tab
class _SavedPinsTab extends StatefulWidget {
  const _SavedPinsTab();

  @override
  State<_SavedPinsTab> createState() => _SavedPinsTabState();
}

class _SavedPinsTabState extends State<_SavedPinsTab> {
  final Set<String> _expandedCollections = <String>{};

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    final pinProv = context.watch<PinProvider>();
    final userProv = context.watch<UserProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUserId.isEmpty) {
        return;
      }
      context.read<PinProvider>().loadSavedPinCollections(currentUserId);
    });

    final savedPins = pinProv.pins
        .where((p) => p.savedByIds.contains(currentUserId))
        .toList();
    savedPins.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (savedPins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.push_pin_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No saved pins yet',
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      );
    }

    final pinsByCollection = <String, List<PinModel>>{};
    for (final pin in savedPins) {
      final collection = pinProv.savedPinCollectionFor(pin.id);
      pinsByCollection.putIfAbsent(collection, () => <PinModel>[]).add(pin);
    }

    final collectionKeys = pinsByCollection.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ...collectionKeys.map((key) {
          final pins = pinsByCollection[key]!;
          final isExpanded = _expandedCollections.contains(key);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CollectionSectionHeader(
                title: '${SoftSymbols.star} $key',
                subtitle: '${pins.length} saved pins',
                isExpanded: isExpanded,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCollections.remove(key);
                    } else {
                      _expandedCollections.add(key);
                    }
                  });
                },
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SavedPinCollectionScreen(
                        collectionName: key,
                        pins: pins,
                      ),
                    ),
                  );
                },
              ),
              AnimatedSwitcher(
                duration: _collectionExpandDuration,
                reverseDuration: _collectionCollapseDuration,
                switchInCurve: _collectionExpandCurve,
                switchOutCurve: _collectionCollapseCurve,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: isExpanded
                    ? Column(
                        key: ValueKey<String>('pins-expanded-$key'),
                        children: pins
                            .map(
                              (pin) => _SavedPinCollectionTile(
                                pin: pin,
                                userProv: userProv,
                                collectionLabel: key,
                              ),
                            )
                            .toList(),
                      )
                    : const SizedBox(
                        key: ValueKey<String>('pins-collapsed'),
                      ),
              ),
              const SizedBox(height: 6),
            ],
          );
        }),
      ],
    );
  }
}

class _SavedPostCollectionScreen extends StatelessWidget {
  final String collectionName;
  final List<PostModel> posts;

  const _SavedPostCollectionScreen({
    required this.collectionName,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('${SoftSymbols.thread} $collectionName'),
        backgroundColor: AppColors.cream,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: posts.length,
        itemBuilder: (_, i) => _PostCard(post: posts[i]),
      ),
    );
  }
}

class _SavedPinCollectionScreen extends StatelessWidget {
  final String collectionName;
  final List<PinModel> pins;

  const _SavedPinCollectionScreen({
    required this.collectionName,
    required this.pins,
  });

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('${SoftSymbols.star} $collectionName'),
        backgroundColor: AppColors.cream,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pins.length,
        itemBuilder: (_, i) => _SavedPinCollectionTile(
          pin: pins[i],
          userProv: userProv,
          collectionLabel: collectionName,
        ),
      ),
    );
  }
}

class _SavedPinCollectionTile extends StatelessWidget {
  final PinModel pin;
  final UserProvider userProv;
  final String? collectionLabel;

  const _SavedPinCollectionTile({
    required this.pin,
    required this.userProv,
    this.collectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pinUser = userProv.getUserById(pin.userId);
    final authorName = pinUser?.displayName ?? pin.username ?? 'Unknown';
    final authorUsername = pinUser?.username ?? pin.username ?? pin.userId;
    final authorAvatar = _resolveAvatarImage(pinUser?.avatarUrl);
    final authorInitial = authorName.isNotEmpty
        ? authorName.substring(0, 1).toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => pin_detail.PinDetailScreen(pin: pin)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.lavender.withOpacity(0.15),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            if (pin.imageUrl != null && pin.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  imageUrl: pin.imageUrl,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pin.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.profile(pin.userId));
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.lavenderLight,
                          backgroundImage: authorAvatar,
                          child: authorAvatar == null
                              ? Text(
                                  authorInitial,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.deepPink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$authorName · @$authorUsername',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (collectionLabel != null &&
                      collectionLabel!.trim().isNotEmpty)
                    Text(
                      'Saved in: $collectionLabel',
                      style: const TextStyle(
                        color: AppColors.lavenderDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (collectionLabel != null &&
                      collectionLabel!.trim().isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    '${pin.likedByIds.length} likes',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
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

// Settings modal
class _SettingsModal extends StatefulWidget {
  const _SettingsModal();

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  late bool _isPublic;
  late bool _preventScreenshots;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  bool _isSavingProfile = false;
  String? _usernameStatus;
  bool? _isUsernameAvailable;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _isPublic = user?.isPublic ?? true;
    _preventScreenshots =
      context.read<ScreenSecurityProvider>().preventScreenshots;
    _nameCtrl.text = user?.displayName ?? '';
    _usernameCtrl.text = user?.username ?? '';
    _bioCtrl.text = user?.bio ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final auth = context.read<AuthProvider>();
    final raw = _usernameCtrl.text.trim();

    if (raw.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameStatus = 'Enter a username first.';
      });
      return;
    }

    final normalized = auth.normalizeUsername(raw);
    _usernameCtrl.text = normalized;
    _usernameCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );

    final available = await auth.isUsernameAvailable(
      normalized,
      excludeUserId: auth.user?.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUsernameAvailable = available;
      _usernameStatus =
          available ? 'Username is available.' : 'Username is already taken.';
    });
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final displayName = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }

    if (username.isEmpty || username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username must be at least 3 characters.'),
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    await auth.updateProfile(
      displayName: displayName,
      username: username,
      bio: _bioCtrl.text.trim(),
      isPublic: _isPublic,
    );

    if (context.mounted) {
      await context.read<UserProvider>().refresh();
    }

    if (!mounted) {
      return;
    }

    setState(() => _isSavingProfile = false);

    if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
      return;
    }

    setState(() {
      _isUsernameAvailable = true;
      _usernameStatus = 'Profile updated.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settings ⚙️',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Your display name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _usernameCtrl,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'username',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: TextButton(
                  onPressed: _checkUsernameAvailability,
                  child: const Text('Check'),
                ),
              ),
            ),
            if (_usernameStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _usernameStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isUsernameAvailable == true
                          ? Colors.green.shade700
                          : (_isUsernameAvailable == false
                              ? Colors.red.shade600
                              : AppColors.textMed),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Write something about yourself...',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSavingProfile ? null : _saveProfile,
                child: _isSavingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save profile'),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.security_rounded, color: AppColors.textMed),
              title: const Text('Profile Privacy',
                  style: TextStyle(
                      color: AppColors.textDark, fontWeight: FontWeight.w500)),
              trailing: Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeThumbColor: AppColors.deepPink,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: AppColors.textMed),
              title: const Text(
                'Prevent screenshots',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                kIsWeb
                    ? 'Available on Android app builds.'
                    : 'Blocks screenshots/screen recording on Android.',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Switch(
                value: _preventScreenshots,
                onChanged: (v) async {
                  setState(() => _preventScreenshots = v);
                  await context
                      .read<ScreenSecurityProvider>()
                      .setPreventScreenshots(v);
                },
                activeThumbColor: AppColors.deepPink,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.deepPink, width: 1),
                ),
                child: Text(
                  _isPublic
                      ? '🌍 Your profile and posts are visible to everyone.'
                      : '🔒 Your profile is private. Others must follow to see your posts.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontStyle: FontStyle.italic,
                      height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  await context.read<JournalProvider>().clearSession();
                  await context.read<MoodProvider>().clearSession();
                  await context.read<NotificationProvider>().clearSession();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/onboarding');
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPink),
                child: const Text('Sign out',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Stat Chip Helper
class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;
  const _StatChip({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepPink)),
              Text(label,
                  style:
                      const TextStyle(color: AppColors.textMed, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// Post Card
class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

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
    final canOpenAuthorProfile = !post.isAnonymous && post.userId.isNotEmpty;
    final postAuthorName = post.isAnonymous
      ? SoftSymbols.anonymous
        : (post.username?.isNotEmpty == true
            ? post.username!
            : (postUser?.displayName.isNotEmpty == true
                ? postUser!.displayName
                : (postUser?.username.isNotEmpty == true
                    ? postUser!.username
                    : 'Unknown')));
    final avatarLabel = post.isAnonymous
      ? SoftSymbols.blossom
        : (postAuthorName.isNotEmpty
            ? postAuthorName.substring(0, 1).toUpperCase()
            : '?');
    final avatarImage = post.isAnonymous
        ? null
        : _resolveAvatarImage(postUser?.avatarUrl ?? post.avatarUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, AppRoutes.post(post.id)),
        child: Container(
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canOpenAuthorProfile
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfileScreen(userId: post.userId),
                            ),
                          );
                        }
                      : null,
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postAuthorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark),
                            ),
                            Text(
                              _timeAgo(post.createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ),
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
                          icon: const Icon(Icons.more_horiz_rounded,
                              color: AppColors.textLight),
                        ),
                    ],
                  ),
                ),
              ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(post.caption,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImage(
                      imageUrl: post.imageUrl,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          postProv.likePost(post.id, auth.user?.id ?? ''),
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color:
                            isLiked ? AppColors.deepPink : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${post.likedByIds.length}',
                        style: const TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text('${post.commentCount}',
                        style: const TextStyle(
                            color: AppColors.textMed,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => showSavePostCollectionSheet(
                        context: context,
                        post: post,
                        postId: post.id,
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isSaved ? AppColors.deepPink : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

/// Other User Profile Screen
class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  const OtherUserProfileScreen({required this.userId, super.key});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showConnectionsSheet({
    required String title,
    required List<String> userIds,
  }) {
    final userProvider = context.read<UserProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SafeArea(
            top: false,
            child: userIds.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No users yet',
                        style: TextStyle(color: AppColors.textMed),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$title (${userIds.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(sheetContext).size.height * 0.55,
                        child: ListView.builder(
                          itemCount: userIds.length,
                          itemBuilder: (_, i) {
                            final id = userIds[i];
                            final listedUser = userProvider.getUserById(id);
                            final displayName =
                                listedUser?.displayName ?? 'User';
                            final username = listedUser?.username ?? id;
                            final avatarImage =
                                _resolveAvatarImage(listedUser?.avatarUrl);
                            final initial = displayName.isNotEmpty
                                ? displayName.substring(0, 1).toUpperCase()
                                : '?';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.lavenderLight,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Text(
                                        initial,
                                        style: const TextStyle(
                                            color: AppColors.deepPink),
                                      )
                                    : null,
                              ),
                              title: Text(displayName),
                              subtitle: Text('@$username'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: listedUser == null
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              OtherUserProfileScreen(
                                                  userId: listedUser.id),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProv = context.watch<UserProvider>();
    final user = userProv.getUserById(widget.userId);

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(backgroundColor: AppColors.cream, elevation: 0),
        body: Center(
          child: Text('User not found',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
      );
    }

    final currentUserId = auth.user?.id;
    final isOwnProfile = currentUserId == widget.userId;
    final isFollowing =
        currentUserId != null && user.followerIds.contains(currentUserId);
    final hasPendingRequest = currentUserId != null &&
        user.pendingFollowRequests.contains(currentUserId);
    final canViewContent = user.isPublic || isFollowing;
    final canMessage = !isOwnProfile && (user.isPublic || isFollowing);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 290,
            backgroundColor: AppColors.cream,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 210) {
                    return const SizedBox.shrink();
                  }

                  return Container(
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildProfileAvatar(
                                displayName: user.displayName,
                                avatarUrl: user.avatarUrl,
                                radius: 44,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      '@${user.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textMed,
                                          fontSize: 13),
                                    ),
                                    if (user.bio != null &&
                                        user.bio!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          user.bio!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.textMed,
                                              fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Stats
                          Row(
                            children: [
                              _StatChip(
                                count: user.followerIds.length,
                                label: 'Followers',
                                onTap: user.isPublic
                                    ? () => _showConnectionsSheet(
                                          title: 'Followers',
                                          userIds: user.followerIds,
                                        )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              _StatChip(
                                count: user.followingIds.length,
                                label: 'Following',
                                onTap: user.isPublic
                                    ? () => _showConnectionsSheet(
                                          title: 'Following',
                                          userIds: user.followingIds,
                                        )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              if (canMessage)
                IconButton(
                  onPressed: () async {
                    try {
                      final authProvider = context.read<AuthProvider>();
                      final actingUserId = authProvider.user?.id;
                      if (actingUserId == null || actingUserId.isEmpty) {
                        return;
                      }

                      final chatProvider = context.read<ChatProvider>();
                      await chatProvider.init(actingUserId);
                      final chatId =
                          await chatProvider.ensureDirectChat(widget.userId);

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pushNamed(context, AppRoutes.chat(chatId));
                    } catch (e) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to open chat: $e')),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.textDark,
                  ),
                  tooltip: 'Message',
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: ElevatedButton(
                    onPressed: isOwnProfile
                        ? null
                        : () async {
                            try {
                              final authProvider =
                                  context.read<AuthProvider>();
                              final actingUserId = authProvider.user?.id;
                              if (actingUserId == null) {
                                return;
                              }

                              if (hasPendingRequest) {
                                await context
                                    .read<FollowProvider>()
                                    .cancelFollowRequest(
                                      currentUserId: actingUserId,
                                      targetUserId: widget.userId,
                                    );
                              } else if (isFollowing) {
                                await context
                                    .read<FollowProvider>()
                                    .unfollowUser(
                                      currentUserId: actingUserId,
                                      targetUserId: widget.userId,
                                    );
                              } else if (user.isPublic) {
                                await context.read<FollowProvider>().followUser(
                                      currentUserId: actingUserId,
                                      targetUserId: widget.userId,
                                    );
                                await context
                                    .read<NotificationProvider>()
                                    .createNotification(
                                      toUserId: widget.userId,
                                      fromUserId: actingUserId,
                                      type: NotificationType.follow,
                                    );
                              } else {
                                await context
                                    .read<FollowProvider>()
                                    .sendFollowRequest(
                                      currentUserId: actingUserId,
                                      targetUserId: widget.userId,
                                    );
                                await context
                                    .read<NotificationProvider>()
                                    .createNotification(
                                      toUserId: widget.userId,
                                      fromUserId: actingUserId,
                                      type: NotificationType.followRequest,
                                    );
                              }

                              await context.read<UserProvider>().refresh();
                              await context
                                  .read<AuthProvider>()
                                  .refreshCurrentUser();
                            } catch (e) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Follow action failed: $e'),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwnProfile
                          ? AppColors.lavender
                          : isFollowing
                              ? AppColors.lavenderLight
                              : AppColors.deepPink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      isOwnProfile
                          ? 'Your Profile'
                          : isFollowing
                              ? 'Following'
                              : hasPendingRequest
                                  ? 'Cancel Request'
                                  : user.isPublic
                                      ? 'Follow'
                                      : 'Request',
                      style: TextStyle(
                        color: isOwnProfile || isFollowing
                            ? AppColors.deepPink
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            bottom: canViewContent
                ? TabBar(
                    controller: _tabs,
                    labelColor: AppColors.deepPink,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.deepPink,
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'Pins & Boards'),
                    ],
                  )
                : null,
          ),
        ],
        body: !canViewContent
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔒', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 20),
                      Text('This account is private',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      const Text('Follow to see their posts and pins',
                          style: TextStyle(
                              color: AppColors.textMed, fontSize: 14)),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  _UserPostsTab(userId: widget.userId),
                  _UserPinsTab(userId: widget.userId),
                ],
              ),
      ),
    );
  }
}
