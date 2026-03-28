import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/soft_symbols.dart';

class CreatePostSheet extends StatefulWidget {
  final String? preSelectedDestination; // 'fyp', 'pin', 'anon'

  const CreatePostSheet({
    super.key,
    this.preSelectedDestination,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  static const double _uploadMediaAspectRatio = 4 / 5;

  // Destination picker
  String _destination = 'fyp'; // fyp, pin, anon

  // Form fields
  final _captionCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  XFile? _selectedImage;

  // Pin-specific
  String? _selectedBoardId;
  bool _isPinPublic = true;
  bool _isLoadingBoards = false;

  // Loading
  bool _isLoading = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedDestination != null) {
      _destination = widget.preSelectedDestination!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        setState(() => _isLoadingBoards = true);
        try {
          await context.read<PinProvider>().loadUserBoards(userId);
          final boards = context.read<PinProvider>().boards;
          if (_selectedBoardId == null && boards.isNotEmpty) {
            _selectedBoardId = boards.first['id'] as String?;
          }
        } finally {
          if (mounted) {
            setState(() => _isLoadingBoards = false);
          }
        }
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _post() async {
    if (_isLoading) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      _showError('Not logged in');
      return;
    }

    // Validate based on destination
    if (_destination == 'fyp' || _destination == 'anon') {
      if (_captionCtrl.text.trim().isEmpty) {
        _showError('Please add a caption');
        return;
      }
    } else if (_destination == 'pin') {
      if (_isLoadingBoards) {
        _showError('Boards are still loading. Please wait a moment.');
        return;
      }
      if (_titleCtrl.text.trim().isEmpty) {
        _showError('Please add a title for your pin');
        return;
      }
      if (_selectedBoardId == null) {
        _showError('Please select a board');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      Uint8List? selectedImageBytes;
      String? selectedImageName;
      if (_selectedImage != null && kIsWeb) {
        selectedImageBytes = await _selectedImage!.readAsBytes();
        selectedImageName = _selectedImage!.name;
      }

      final tags =
          _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

      if (_destination == 'fyp') {
        // Create FYP post
        await context.read<PostProvider>().createPost(
          userId: user.id,
          caption: _captionCtrl.text.trim(),
          imageUrl: _selectedImage?.path,
          imageBytes: selectedImageBytes,
          imageFileName: selectedImageName,
          isAnonymous: false,
          tags: tags,
        );
        await context.read<PostProvider>().reloadFeed(reset: true);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared! ${SoftSymbols.blossom}'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_destination == 'anon') {
        // Create anonymous post
        await context.read<PostProvider>().createPost(
          userId: user.id,
          caption: _captionCtrl.text.trim(),
          imageUrl: _selectedImage?.path,
          imageBytes: selectedImageBytes,
          imageFileName: selectedImageName,
          isAnonymous: true,
          tags: tags,
        );
        await context.read<PostProvider>().reloadFeed(reset: true);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anonymous post shared.'), duration: Duration(seconds: 2)),
        );
      } else if (_destination == 'pin') {
        // Create pin
        await context.read<PinProvider>().createPin(
          userId: user.id,
          title: _titleCtrl.text.trim(),
          boardId: _selectedBoardId!,
          imageUrl: _selectedImage?.path,
          imageBytes: selectedImageBytes,
          imageFileName: selectedImageName,
          description: _captionCtrl.text.trim(),
          isPublic: _isPinPublic,
          tags: tags,
        );
        await context.read<PinProvider>().reloadPublicPins(reset: true);
        await context.read<PinProvider>().loadUserBoards(user.id);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pin saved.'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      _showError('Failed to post: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinProvider = context.watch<PinProvider>();

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.softPink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Create Something ${SoftSymbols.blossom}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),

              // Destination picker buttons
              Row(
                children: [
                  _DestinationButton(
                    label: 'FYP\nPost',
                    icon: Icons.home_rounded,
                    isSelected: _destination == 'fyp',
                    onTap: () => setState(() => _destination = 'fyp'),
                  ),
                  const SizedBox(width: 12),
                  _DestinationButton(
                    label: 'Pins\nBoard',
                    icon: Icons.push_pin_rounded,
                    isSelected: _destination == 'pin',
                    onTap: () => setState(() => _destination = 'pin'),
                  ),
                  const SizedBox(width: 12),
                  _DestinationButton(
                    label: 'Anon\nPost',
                    icon: Icons.favorite_rounded,
                    isSelected: _destination == 'anon',
                    onTap: () => setState(() => _destination = 'anon'),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20),

              // Image picker
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedImage == null
                          ? AppColors.softPink
                          : AppColors.deepPink,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.lavenderLight,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_outlined, 
                              color: AppColors.deepPink, 
                              size: 32
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add image',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: AppColors.deepPink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auto-crop ratio: 4:5',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.textMed),
                            ),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: _uploadMediaAspectRatio,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImage!.path,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        )
                                      : Image.file(
                                          File(_selectedImage!.path),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                ),
                              ),
                            ),
                            Container(
                              color: Colors.black26,
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Title field (for pins)
              if (_destination == 'pin') ...[
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pin title (required)',
                    hintStyle: const TextStyle(color: AppColors.textLight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.softPink),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.softPink),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.deepPink, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 12),
              ],

              // Caption field
              TextField(
                controller: _captionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _destination == 'pin'
                      ? 'Description (optional)'
                      : 'What\'s on your mind? (required)',
                  hintStyle: const TextStyle(color: AppColors.textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softPink),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softPink),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.deepPink, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 12),

              // Board selector (for pins)
              if (_destination == 'pin') ...[
                Text(
                  'Select Board',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final boards = pinProvider.boards;
                    if (_selectedBoardId == null && boards.isNotEmpty) {
                      _selectedBoardId = boards.first['id'] as String?;
                    }

                    if (_isLoadingBoards) {
                      return const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Loading boards...'),
                        ],
                      );
                    }

                    return boards.isEmpty
                        ? Text(
                            'No boards yet. Create one first.',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textLight),
                          )
                        : DropdownButton<String>(
                            value: _selectedBoardId,
                            hint: const Text('Choose a board'),
                            isExpanded: true,
                            items: boards
                                .map((board) => DropdownMenuItem<String>(
                                      value: board['id'] as String,
                                      child: Text(board['name'] as String),
                                    ))
                                .toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() => _selectedBoardId = value);
                                  },
                          );
                  },
                ),
                const SizedBox(height: 12),

                // Public toggle (for pins)
                Row(
                  children: [
                    const Icon(Icons.public_rounded, color: AppColors.deepPink),
                    const SizedBox(width: 8),
                    Text(
                      'Show in Discover',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    Switch(
                      value: _isPinPublic,
                      activeThumbColor: AppColors.deepPink,
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() => _isPinPublic = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Tags input
              TextField(
                controller: _tagsCtrl,
                decoration: InputDecoration(
                  hintText: 'Tags (comma-separated)',
                  hintStyle: const TextStyle(color: AppColors.textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softPink),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softPink),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.deepPink, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),

              // Post button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _post,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPink,
                    disabledBackgroundColor: AppColors.softPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _destination == 'fyp'
                              ? 'Post to Feed'
                              : _destination == 'anon'
                                  ? 'Post Anonymously'
                                  : 'Save to Board',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DestinationButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.deepPink : AppColors.lavenderLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.deepPink : AppColors.softPink,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.deepPink,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.deepPink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
