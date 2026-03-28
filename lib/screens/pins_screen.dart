import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/app_image.dart';
import '../widgets/create_post_sheet.dart';
import '../widgets/save_pin_collection_sheet.dart';
import '../utils/avatar_utils.dart';
import '../utils/search_utils.dart';
import '../utils/soft_symbols.dart';
import 'pin_detail_screen.dart' as pin_detail;

class PinsScreen extends StatefulWidget {
  const PinsScreen({super.key});
  @override
  State<PinsScreen> createState() => _PinsScreenState();
}

class _PinsScreenState extends State<PinsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _activeTabIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) {
        return;
      }
      setState(() => _activeTabIndex = _tabs.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: const Text('Pins & Boards',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
        actions: [
          if (kIsWeb)
            Consumer<MediaLayoutProvider>(
              builder: (context, mediaLayout, _) {
                final useContainOnWeb = mediaLayout.useContainOnWeb;
                return IconButton(
                  icon: Icon(
                    useContainOnWeb
                        ? Icons.fit_screen_rounded
                        : Icons.crop_rounded,
                    color: AppColors.textDark,
                  ),
                  tooltip:
                      useContainOnWeb ? 'Image mode: Fit' : 'Image mode: Fill',
                  onPressed: () =>
                      context.read<MediaLayoutProvider>().toggleMode(),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textDark),
            onPressed: () => _showSearchDialog(context),
          ),
          if (_searchQuery.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textDark),
              onPressed: () => setState(() => _searchQuery = ''),
              tooltip: 'Back to all',
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.deepPink),
            onPressed: () => _showAddPin(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.deepPink,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.deepPink,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Boards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DiscoverTab(
            searchQuery: _searchQuery,
            onClearSearch: () => setState(() => _searchQuery = ''),
          ),
          _MyBoardsTab(
            searchQuery: _searchQuery,
            onClearSearch: () => setState(() => _searchQuery = ''),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'pins_fab',
        onPressed: () => _showAddPin(context),
        backgroundColor: AppColors.deepPink,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    final searchScope = _activeTabIndex == 0 ? 'pins' : 'boards';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Search $searchScope',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Type keyword...',
            prefixIcon: Icon(Icons.search, color: AppColors.deepPink),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _searchQuery = searchCtrl.text);
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showAddPin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(preSelectedDestination: 'pin'),
    );
  }
}

// DISCOVER TAB - All public pins from all users
class _DiscoverTab extends StatefulWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;
  const _DiscoverTab({required this.searchQuery, required this.onClearSearch});

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isPaginating = false;

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
    if (_isPaginating || !_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels < threshold) {
      return;
    }

    final pinProvider = context.read<PinProvider>();
    if (!pinProvider.hasMoreDiscoverPins) {
      return;
    }

    _isPaginating = true;
    try {
      await pinProvider.loadMorePublicPins();
    } finally {
      _isPaginating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins = context.watch<PinProvider>().pins;
    final users = context.watch<UserProvider>();
    final pinProvider = context.watch<PinProvider>();
    final tokens = searchTokens(widget.searchQuery);

    // Filter: show public pins from public users
    var filteredPins = pins.where((pin) {
      if (!pin.isPublic) return false; // Only public pins

      final user = users.getUserById(pin.userId);
      if (user == null || !user.isPublic)
        return false; // Only from public accounts

      if (tokens.isEmpty) return true;
      return matchesAnySearchField(
        fields: <String>[pin.title, pin.description ?? '', pin.tags.join(' ')],
        tokens: tokens,
      );
    }).toList();

    // Sort by recency
    filteredPins.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredPins.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(
            Icons.push_pin_rounded,
            size: 48,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          Text(
              widget.searchQuery.isEmpty
                  ? 'No pins to discover yet'
                  : 'No pins found',
              style: Theme.of(context).textTheme.headlineSmall),
          if (widget.searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onClearSearch,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to all pins'),
            ),
          ],
        ]),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = kIsWeb
        ? (width >= 1400
            ? 4
            : width >= 1000
                ? 3
                : 2)
        : 2;

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount:
          filteredPins.length + (pinProvider.hasMoreDiscoverPins ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= filteredPins.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.deepPink),
            ),
          );
        }
        return _PinCard(pin: filteredPins[i]);
      },
    );
  }
}

// MY BOARDS TAB - Only current user's boards
class _MyBoardsTab extends StatefulWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;
  const _MyBoardsTab({required this.searchQuery, required this.onClearSearch});

  @override
  State<_MyBoardsTab> createState() => _MyBoardsTabState();
}

class _MyBoardsTabState extends State<_MyBoardsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        await context.read<PinProvider>().loadUserBoards(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pinProv = context.watch<PinProvider>();

    if (auth.user == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          Text('Please log in',
              style: Theme.of(context).textTheme.headlineSmall),
        ]),
      );
    }

    // Get all boards for current user from Firestore (stored in provider)
    // For Phase 5, we'll show boards from local provider data
    final userBoards = pinProv.boards.isNotEmpty
        ? pinProv.boards.where((b) => b['userId'] == auth.user!.id).toList()
        : <Map<String, dynamic>>[];

    final boardTokens = searchTokens(widget.searchQuery);
    final filteredBoards = boardTokens.isEmpty
        ? userBoards
        : userBoards.where((board) {
            final boardName = (board['name'] ?? '').toString();
            final boardDesc = (board['description'] ?? '').toString();
            return matchesAnySearchField(
              fields: <String>[boardName, boardDesc],
              tokens: boardTokens,
            );
          }).toList();

    if (filteredBoards.isEmpty && widget.searchQuery.trim().isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text('No boards found',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onClearSearch,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to all boards'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: filteredBoards.length + 1,
      itemBuilder: (_, i) {
        // Add new board button
        if (i == filteredBoards.length) {
          return GestureDetector(
            onTap: () => _showCreateBoard(context),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.softPink, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 36, color: AppColors.deepPink),
                  SizedBox(height: 8),
                  Text('New board',
                      style: TextStyle(
                          color: AppColors.deepPink,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }

        final board = filteredBoards[i];
        final boardId = board['id'] as String;
        final boardName = board['name'] as String;
        final pinCount = pinProv.pins.where((p) => p.boardId == boardId).length;

        const colors = [
          AppColors.softPink,
          AppColors.lavender,
          AppColors.beige,
          AppColors.pink
        ];

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BoardDetailScreen(boardId: boardId)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors[i % colors.length],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Text(SoftSymbols.star,
                    style: TextStyle(
                        fontSize: 60, color: Colors.white.withOpacity(0.3))),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(boardName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textDark)),
                    Text('$pinCount pins',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMed)),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _showCreateBoard(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Board',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Board name...',
            prefixIcon: Icon(Icons.folder_outlined, color: AppColors.deepPink),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a board name.')),
                );
                return;
              }
              if (auth.user != null) {
                await context.read<PinProvider>().createBoard(
                      userId: auth.user!.id,
                      name: name,
                      description: '',
                      isPublic: true,
                    );
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Board created successfully.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// PIN CARD in grid
class _PinCard extends StatelessWidget {
  final PinModel pin;
  const _PinCard({required this.pin});
  static const double _pinMediaAspectRatio = 4 / 5;

  Future<void> _confirmDeletePin(
    BuildContext context,
    PinProvider pinProvider,
  ) async {
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
      await pinProvider.deletePin(pin.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin deleted.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete pin: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final pinProvider = context.read<PinProvider>();
    final currentUserId = auth.user?.id ?? '';
    final isLiked =
        currentUserId.isNotEmpty && pin.likedByIds.contains(currentUserId);
    final isSaved =
        currentUserId.isNotEmpty && pin.savedByIds.contains(currentUserId);
    final isOwnPin = currentUserId.isNotEmpty && pin.userId == currentUserId;
    final pinUser = userProvider.getUserById(pin.userId);
    final authorName = pinUser?.displayName ?? pin.username ?? 'Unknown';
    final authorUsername = pinUser?.username ?? pin.username ?? pin.userId;
    final authorAvatar = resolveAvatarImage(pinUser?.avatarUrl);
    final authorInitial =
        authorName.isNotEmpty ? authorName.substring(0, 1).toUpperCase() : '?';
    final mediaLayout = context.watch<MediaLayoutProvider>();
    final useContainOnWeb = kIsWeb && mediaLayout.useContainOnWeb;
    final mediaFit = useContainOnWeb ? BoxFit.contain : BoxFit.cover;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => pin_detail.PinDetailScreen(pin: pin)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pin.imageUrl != null && pin.imageUrl!.isNotEmpty
                ? AspectRatio(
                    aspectRatio: _pinMediaAspectRatio,
                    child: Container(
                      color: AppColors.cream,
                      child: AppImage(
                        imageUrl: pin.imageUrl,
                        fit: mediaFit,
                        width: double.infinity,
                      ),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: _pinMediaAspectRatio,
                    child: Container(
                      color: AppColors.lavenderLight,
                      child: Center(
                        child: Text(
                          pin.title.split(' ').last,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                              context, AppRoutes.profile(pin.userId));
                        },
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.lavenderLight,
                          backgroundImage: authorAvatar,
                          child: authorAvatar == null
                              ? Text(
                                  authorInitial,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.deepPink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                                context, AppRoutes.profile(pin.userId));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '@$authorUsername',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isOwnPin)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmDeletePin(context, pinProvider);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete pin'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pin.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: currentUserId.isEmpty
                            ? null
                            : () async {
                                if (isLiked) {
                                  await pinProvider.unlikePin(
                                      pin.id, currentUserId);
                                } else {
                                  await pinProvider.likePin(
                                      pin.id, currentUserId);
                                }
                              },
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: AppColors.deepPink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${pin.likedByIds.length}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMed),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: currentUserId.isEmpty
                            ? null
                            : () async {
                                await showSavePinCollectionSheet(
                                  context: context,
                                  pinId: pin.id,
                                  userId: currentUserId,
                                  wasSaved: isSaved,
                                );
                              },
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 16,
                          color: AppColors.deepPink,
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

// BOARD DETAIL SCREEN
class BoardDetailScreen extends StatelessWidget {
  final String boardId;
  const BoardDetailScreen({required this.boardId, super.key});

  Future<void> _confirmDeleteBoard(
    BuildContext context, {
    required PinProvider pinProvider,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete board?'),
        content: const Text('This board will be removed permanently.'),
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
      await pinProvider.deleteBoard(boardId);
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board deleted.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete board: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pinProv = context.watch<PinProvider>();
    final users = context.watch<UserProvider>();

    // Find board info and its pins
    final board = pinProv.boards.firstWhere(
      (b) => b['id'] == boardId,
      orElse: () => <String, dynamic>{},
    );

    final boardPins = pinProv.pins.where((p) => p.boardId == boardId).toList();

    if (board.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          title: const Text('Board',
              style: TextStyle(
                  color: AppColors.textDark, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Text('Board not found',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
      );
    }

    final boardName = board['name'] as String;
    final boardOwnerId = (board['userId'] ?? '').toString();
    final isOwnBoard = auth.user?.id != null && auth.user!.id == boardOwnerId;
    final filteredPins = boardPins.where((pin) {
      final user = users.getUserById(pin.userId);
      return user != null && user.isPublic && pin.isPublic;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(boardName,
            style: const TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700)),
        actions: [
          if (isOwnBoard)
            IconButton(
              onPressed: () =>
                  _confirmDeleteBoard(context, pinProvider: pinProv),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.deepPink),
              tooltip: 'Delete board',
            ),
        ],
      ),
      body: filteredPins.isEmpty
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
          : MasonryGridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: kIsWeb
                  ? (MediaQuery.of(context).size.width >= 1200 ? 3 : 2)
                  : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: filteredPins.length,
              itemBuilder: (_, i) => _PinCard(pin: filteredPins[i]),
            ),
    );
  }
}
