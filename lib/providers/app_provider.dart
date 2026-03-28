import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/screenshot_security_service.dart';
import '../utils/search_utils.dart';

enum WebImageMode { fit, fill }

class MediaLayoutProvider extends ChangeNotifier {
  static const String _prefKey = 'web_image_mode';

  WebImageMode _mode = WebImageMode.fit;
  bool _isLoaded = false;

  WebImageMode get mode => _mode;
  bool get useContainOnWeb => _mode == WebImageMode.fit;

  Future<void> init() async {
    if (_isLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == WebImageMode.fill.name) {
      _mode = WebImageMode.fill;
    } else {
      _mode = WebImageMode.fit;
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleMode() async {
    _mode = _mode == WebImageMode.fit ? WebImageMode.fill : WebImageMode.fit;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _mode.name);
  }
}

class ScreenSecurityProvider extends ChangeNotifier {
  static const String _prefKey = 'prevent_screenshots';

  bool _preventScreenshots = false;
  bool _isLoaded = false;

  bool get preventScreenshots => _preventScreenshots;

  Future<void> init() async {
    if (_isLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _preventScreenshots = prefs.getBool(_prefKey) ?? false;
    _isLoaded = true;

    await ScreenshotSecurityService.setProtectionEnabled(_preventScreenshots);
    notifyListeners();
  }

  Future<void> setPreventScreenshots(bool enabled) async {
    _preventScreenshots = enabled;
    notifyListeners();

    await ScreenshotSecurityService.setProtectionEnabled(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _requiresEmailVerification = false;
  String? _verificationEmail;

  late final AuthService _authService;
  late final FirestoreService _firestoreService;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  bool get requiresEmailVerification => _requiresEmailVerification;
  String? get verificationEmail => _verificationEmail;

  AuthProvider() {
    _authService = AuthService();
    _firestoreService = FirestoreService();
  }

  Future<void> init() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      _user = null;
      _requiresEmailVerification = false;
      _verificationEmail = null;
      notifyListeners();
      return;
    }

    try {
      final isVerified = await _authService.isCurrentUserEmailVerified();
      if (!isVerified) {
        _error = 'Please verify your email before signing in.';
        _requiresEmailVerification = true;
        _verificationEmail = firebaseUser.email;
        _user = null;
        await _authService.logout();
        notifyListeners();
        return;
      }

      final userData = await _firestoreService.getUser(firebaseUser.uid);
      if (userData != null) {
        _user = userData;
        _requiresEmailVerification = false;
        _verificationEmail = null;
      } else {
        final recovered = await _recoverMissingProfile(
          userId: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          usernameHint: (firebaseUser.email ?? '').split('@').first,
          displayNameHint: firebaseUser.displayName,
        );

        if (recovered != null) {
          _user = recovered;
          _requiresEmailVerification = false;
          _verificationEmail = null;
          _error = null;
        } else {
          _error = 'Account profile is missing. Please sign in again.';
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      final authUser =
          await _authService.login(email: email, password: password);
      if (authUser == null) {
        _error = 'Login failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final isVerified = await _authService.isCurrentUserEmailVerified();
      if (!isVerified) {
        String? verificationSendError;
        try {
          await _authService.sendEmailVerification();
        } catch (e) {
          verificationSendError = e.toString();
        }
        await _authService.logout();
        _user = null;
        _requiresEmailVerification = true;
        _verificationEmail = email;
        _error = verificationSendError == null
            ? 'Email not verified. We sent you a verification link. Please verify and sign in again.'
            : 'Email not verified. Please verify your inbox. Resend failed: $verificationSendError';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final firestoreUser = await _firestoreService.getUser(authUser.id);
      if (firestoreUser == null) {
        final recovered = await _recoverMissingProfile(
          userId: authUser.id,
          email: authUser.email,
          usernameHint: authUser.username,
          displayNameHint: authUser.displayName,
        );

        if (recovered == null) {
          _error =
              'Profile setup incomplete and auto-repair failed. Please contact support.';
          await _authService.logout();
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _user = recovered;
        _requiresEmailVerification = false;
        _verificationEmail = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _user = firestoreUser;
      _requiresEmailVerification = false;
      _verificationEmail = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(
    String email,
    String username,
    String displayName,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userModel = await _authService.signup(
        email: email,
        username: username,
        displayName: displayName,
        password: password,
      );

      if (userModel == null) {
        _error = 'Signup failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _firestoreService.createUser(userModel);
      String? verificationSendError;
      try {
        await _authService.sendEmailVerification();
      } catch (e) {
        verificationSendError = e.toString();
      }
      await _authService.logout();

      _user = null;
      _requiresEmailVerification = true;
      _verificationEmail = email;
      _error = verificationSendError;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _requiresEmailVerification = false;
    _verificationEmail = null;
    notifyListeners();
  }

  Future<bool> resendEmailVerification(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authUser =
          await _authService.login(email: email, password: password);
      if (authUser == null) {
        _error = 'Could not sign in to resend verification email.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final alreadyVerified = await _authService.isCurrentUserEmailVerified();
      if (alreadyVerified) {
        _requiresEmailVerification = false;
        _verificationEmail = null;
        _error = 'Your email is already verified. Please sign in.';
        await _authService.logout();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      String? verificationSendError;
      try {
        await _authService.sendEmailVerification();
      } catch (e) {
        verificationSendError = e.toString();
      }
      await _authService.logout();

      if (verificationSendError != null) {
        _error = verificationSendError;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = null;
      _requiresEmailVerification = true;
      _verificationEmail = email;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkEmailVerificationStatus(
    String email,
    String password, {
    bool loginIfVerified = true,
    bool silentWhenUnverified = false,
  }) async {
    _isLoading = true;
    if (!silentWhenUnverified) {
      _error = null;
    }
    notifyListeners();

    try {
      final authUser =
          await _authService.login(email: email, password: password);
      if (authUser == null) {
        _error = 'Could not sign in to check verification status.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final isVerified = await _authService.isCurrentUserEmailVerified();
      if (!isVerified) {
        await _authService.logout();
        _user = null;
        _requiresEmailVerification = true;
        _verificationEmail = email;
        if (!silentWhenUnverified) {
          _error =
              'Email is still not verified. Check inbox/spam and try again.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!loginIfVerified) {
        await _authService.logout();
        _requiresEmailVerification = false;
        _verificationEmail = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final firestoreUser = await _firestoreService.getUser(authUser.id);
      if (firestoreUser == null) {
        final recovered = await _recoverMissingProfile(
          userId: authUser.id,
          email: authUser.email,
          usernameHint: authUser.username,
          displayNameHint: authUser.displayName,
        );

        if (recovered == null) {
          _error =
              'Profile setup incomplete and auto-repair failed. Please sign in again.';
          await _authService.logout();
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _user = recovered;
        _requiresEmailVerification = false;
        _verificationEmail = null;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _user = firestoreUser;
      _requiresEmailVerification = false;
      _verificationEmail = null;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<UserModel?> _recoverMissingProfile({
    required String userId,
    required String email,
    String? usernameHint,
    String? displayNameHint,
  }) async {
    try {
      final fallbackUsername = _safeUsername(
        usernameHint?.trim().isNotEmpty == true
            ? usernameHint!.trim()
            : email.split('@').first,
      );

      final fallbackDisplayName = (displayNameHint?.trim().isNotEmpty == true)
          ? displayNameHint!.trim()
          : fallbackUsername;

      final recovered = UserModel(
        id: userId,
        username: fallbackUsername,
        displayName: fallbackDisplayName,
        email: email,
        createdAt: DateTime.now(),
        isPublic: true,
      );

      await _firestoreService.createUser(recovered);
      return await _firestoreService.getUser(userId) ?? recovered;
    } catch (_) {
      return null;
    }
  }

  String _safeUsername(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (normalized.isEmpty) {
      return 'bloomy_user';
    }

    return normalized;
  }

  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarUrl,
    Uint8List? avatarBytes,
    String? avatarFileName,
    bool? isPublic,
  }) async {
    if (_user == null) {
      return;
    }

    try {
      _error = null;

      String? resolvedAvatarUrl = _user!.avatarUrl;
      if (avatarUrl != null || (avatarBytes != null && avatarBytes.isNotEmpty)) {
        resolvedAvatarUrl = await _firestoreService.uploadUserAvatar(
          userId: _user!.id,
          imagePathOrUrl: avatarUrl,
          imageBytes: avatarBytes,
          imageFileName: avatarFileName,
        );
      }

      var resolvedUsername = _user!.username;
      if (username != null) {
        final normalized = _safeUsername(username.trim());
        if (normalized.length < 3) {
          _error = 'Username must be at least 3 characters.';
          notifyListeners();
          return;
        }

        if (normalized != _user!.username) {
          final available =
              await isUsernameAvailable(normalized, excludeUserId: _user!.id);
          if (!available) {
            _error = 'Username is already taken.';
            notifyListeners();
            return;
          }
        }

        resolvedUsername = normalized;
      }

      _user = UserModel(
        id: _user!.id,
        username: resolvedUsername,
        displayName: displayName ?? _user!.displayName,
        bio: bio ?? _user!.bio,
        avatarUrl: resolvedAvatarUrl,
        email: _user!.email,
        createdAt: _user!.createdAt,
        isPublic: isPublic ?? _user!.isPublic,
        followerIds: _user!.followerIds,
        followingIds: _user!.followingIds,
        pendingFollowRequests: _user!.pendingFollowRequests,
        pronouns: _user!.pronouns,
        website: _user!.website,
      );

      await _firestoreService.updateUser(_user!.id, {
        'username': _user!.username,
        'displayName': _user!.displayName,
        'bio': _user!.bio,
        'avatarUrl': _user!.avatarUrl,
        'isPublic': _user!.isPublic,
      });

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  String normalizeUsername(String raw) => _safeUsername(raw);

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    final normalized = _safeUsername(username);
    final existing = await _firestoreService.getUserByUsername(normalized);
    if (existing == null) {
      return true;
    }

    final ignoredUserId = excludeUserId ?? _user?.id;
    return existing.id == ignoredUserId;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUser() async {
    if (_user == null) {
      return;
    }

    try {
      final refreshed = await _firestoreService.getUser(_user!.id);
      if (refreshed != null) {
        _user = refreshed;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

class PostProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  final int _pageSize = 20;

  List<PostModel> _posts = [];
  List<PostModel> _userPosts = [];

  DocumentSnapshot? _feedCursor;
  bool _hasMoreFeed = true;
  bool _isLoadingFeed = false;

  String? _userPostsOwner;
  DocumentSnapshot? _userPostsCursor;
  bool _hasMoreUserPosts = true;
  bool _isLoadingUserPosts = false;

  List<PostModel> get posts => _posts;
  List<PostModel> get userPosts => _userPosts;
  List<PostModel> get anonPosts =>
      _posts.where((post) => post.isAnonymous).toList();
  List<PostModel> get publicPosts =>
      _posts.where((post) => !post.isAnonymous).toList();
  bool get hasMoreFeed => _hasMoreFeed;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get hasMoreUserPosts => _hasMoreUserPosts;

  Future<void> init() async {
    await reloadFeed(reset: true);
  }

  Future<void> reloadFeed({bool reset = false}) async {
    if (_isLoadingFeed) {
      return;
    }

    if (reset) {
      _feedCursor = null;
      _hasMoreFeed = true;
      _posts = [];
      notifyListeners();
    }

    if (!_hasMoreFeed) {
      return;
    }

    _isLoadingFeed = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getFeedPostsPage(
        startAfter: _feedCursor,
        limit: _pageSize,
      );
      _feedCursor = page.lastDocument;
      _hasMoreFeed = page.hasMore;
      _posts = _mergePosts(existing: _posts, incoming: page.items);
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<List<PostModel>> loadMorePublicPosts() async {
    final before = _posts.length;
    await reloadFeed(reset: false);
    if (_posts.length <= before) {
      return [];
    }
    return _posts.sublist(before);
  }

  Future<void> loadUserPosts(
    String userId, {
    bool reset = true,
  }) async {
    if (_isLoadingUserPosts) {
      return;
    }

    if (reset || _userPostsOwner != userId) {
      _userPostsOwner = userId;
      _userPostsCursor = null;
      _hasMoreUserPosts = true;
      _userPosts = [];
      notifyListeners();
    }

    if (!_hasMoreUserPosts) {
      return;
    }

    _isLoadingUserPosts = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getUserPostsPage(
        userId: userId,
        startAfter: _userPostsCursor,
        limit: _pageSize,
      );
      _userPostsCursor = page.lastDocument;
      _hasMoreUserPosts = page.hasMore;
      _userPosts = _mergePosts(existing: _userPosts, incoming: page.items);

      if (userId == _userPostsOwner) {
        _posts = _mergePosts(existing: _posts, incoming: page.items);
      }
    } finally {
      _isLoadingUserPosts = false;
      notifyListeners();
    }
  }

  Future<List<PostModel>> loadMoreUserPosts(String userId) async {
    final before = _userPosts.length;
    await loadUserPosts(userId, reset: false);
    if (_userPosts.length <= before) {
      return [];
    }
    return _userPosts.sublist(before);
  }

  Future<PostModel?> fetchPostById(String postId) async {
    final post = await _firestoreService.getPost(postId);
    if (post != null) {
      _upsertPost(post);
    }
    return post;
  }

  Future<List<PostModel>> getFollowingPosts(List<String> followingIds) async {
    try {
      return await _firestoreService.getFollowingPosts(
        followingIds: followingIds,
        limit: _pageSize,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<PostModel>> getAnonymousPosts() async {
    try {
      final page =
          await _firestoreService.getAnonymousPostsPage(limit: _pageSize);
      return page.items;
    } catch (_) {
      return [];
    }
  }

  Future<String?> createPost({
    required String userId,
    required String caption,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageFileName,
    bool isAnonymous = false,
    List<String> tags = const [],
  }) async {
    try {
      final postId = await _firestoreService.createPost(
        userId: userId,
        caption: caption,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        isAnonymous: isAnonymous,
        tags: tags,
      );

      await reloadFeed(reset: true);
      if (_userPostsOwner == userId) {
        await loadUserPosts(userId, reset: true);
      }
      return postId;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      await _firestoreService.likePost(postId, userId);
      await _refreshPost(postId);
    } catch (e) {
      throw Exception('Failed to like post: $e');
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _firestoreService.unlikePost(postId, userId);
      await _refreshPost(postId);
    } catch (e) {
      throw Exception('Failed to unlike post: $e');
    }
  }

  Future<void> updateCommentCount(String postId, int newCount) async {
    try {
      await _firestoreService.updatePost(postId, {
        'commentCount': newCount,
      });
      await _refreshPost(postId);
    } catch (e) {
      throw Exception('Failed to update comment count: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestoreService.deletePost(postId);
      _posts.removeWhere((post) => post.id == postId);
      _userPosts.removeWhere((post) => post.id == postId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<void> editPost({
    required String postId,
    required String caption,
    List<String>? tags,
    PostVisibility? visibility,
  }) async {
    try {
      await _firestoreService.updatePost(postId, {
        'caption': caption.trim(),
        if (tags != null) 'tags': tags,
        if (visibility != null)
          'visibility': visibility.toString().split('.').last,
      });
      await _refreshPost(postId);
    } catch (e) {
      throw Exception('Failed to edit post: $e');
    }
  }

  Future<void> _refreshPost(String postId) async {
    final refreshed = await _firestoreService.getPost(postId);
    if (refreshed == null) {
      _posts.removeWhere((post) => post.id == postId);
      _userPosts.removeWhere((post) => post.id == postId);
      notifyListeners();
      return;
    }

    _upsertPost(refreshed);
  }

  void _upsertPost(PostModel post) {
    final postIndex = _posts.indexWhere((candidate) => candidate.id == post.id);
    if (postIndex == -1) {
      _posts.add(post);
    } else {
      _posts[postIndex] = post;
    }

    final userIndex =
        _userPosts.indexWhere((candidate) => candidate.id == post.id);
    if (userIndex != -1) {
      _userPosts[userIndex] = post;
    }

    _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _userPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  List<PostModel> _mergePosts({
    required List<PostModel> existing,
    required List<PostModel> incoming,
  }) {
    final deduped = <String, PostModel>{
      for (final post in existing) post.id: post,
      for (final post in incoming) post.id: post,
    };
    final merged = deduped.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}

class JournalProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StreamSubscription<List<JournalEntry>>? _entriesSubscription;
  List<JournalEntry> _entries = [];
  String? _activeUserId;
  bool _isLoading = false;

  bool _biometricLockEnabled = false;
  bool _isUnlockedForSession = true;

  List<JournalEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get biometricLockEnabled => _biometricLockEnabled;
  bool get isLocked => _biometricLockEnabled && !_isUnlockedForSession;
  int get currentStreak => _calculateStreak(_entries);

  Future<void> init([String? userId]) async {
    if (userId == null || userId.isEmpty) {
      _entries = [];
      _activeUserId = null;
      _isLoading = false;
      _biometricLockEnabled = false;
      _isUnlockedForSession = true;
      notifyListeners();
      return;
    }

    if (_activeUserId == userId && _entriesSubscription != null) {
      return;
    }

    _isLoading = true;
    _activeUserId = userId;
    notifyListeners();

    await _migrateLegacyJournalEntriesIfNeeded(userId);

    await _entriesSubscription?.cancel();
    await _loadBiometricPreference(userId);

    _entriesSubscription =
        _firestoreService.watchJournalEntries(userId).listen((incomingEntries) {
      _entries = incomingEntries..sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addEntry(JournalEntry entry) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not initialized for journal.');
    }

    final now = DateTime.now();
    final resolvedEntry = JournalEntry(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      mood: entry.mood,
      date: entry.date,
      createdAt: entry.createdAt,
      updatedAt: now,
      tags: entry.tags,
      isPrivate: entry.isPrivate,
      coverEmoji: entry.coverEmoji,
    );

    await _firestoreService.saveJournalEntry(
      userId: userId,
      entry: resolvedEntry,
    );
  }

  Future<void> deleteEntry(String id) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not initialized for journal.');
    }

    await _firestoreService.deleteJournalEntry(
      userId: userId,
      entryId: id,
    );
  }

  Future<bool> setBiometricLockEnabled(bool enabled) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    try {
      if (enabled) {
        final deviceSupported = await _localAuth.isDeviceSupported();
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final availableBiometrics = await _localAuth.getAvailableBiometrics();

        if (!deviceSupported && !canCheckBiometrics) {
          return false;
        }

        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Enable biometric lock for your journal',
          options: AuthenticationOptions(
            biometricOnly: availableBiometrics.isNotEmpty,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (!didAuthenticate) {
          return false;
        }
      }

      await _secureStorage.write(
        key: _biometricStorageKey(userId),
        value: enabled.toString(),
      );

      _biometricLockEnabled = enabled;
      _isUnlockedForSession = !enabled;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometric() async {
    if (!_biometricLockEnabled) {
      _isUnlockedForSession = true;
      notifyListeners();
      return true;
    }

    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock your private journal',
        options: AuthenticationOptions(
          biometricOnly: availableBiometrics.isNotEmpty,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        _isUnlockedForSession = true;
        notifyListeners();
      }

      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<void> lockForSession() async {
    if (!_biometricLockEnabled) {
      return;
    }

    _isUnlockedForSession = false;
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _entries = [];
    _activeUserId = null;
    _biometricLockEnabled = false;
    _isUnlockedForSession = true;
    notifyListeners();
  }

  Future<void> _loadBiometricPreference(String userId) async {
    final stored = await _secureStorage.read(key: _biometricStorageKey(userId));
    _biometricLockEnabled = stored == 'true';
    _isUnlockedForSession = !_biometricLockEnabled;
  }

  Future<void> _migrateLegacyJournalEntriesIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final markerKey = 'legacy_journal_migrated_$userId';
    if (prefs.getBool(markerKey) == true) {
      return;
    }

    final raw = prefs.getString('journal');
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(markerKey, true);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final entry = JournalEntry.fromMap(Map<String, dynamic>.from(item));
            await _firestoreService.saveJournalEntry(
              userId: userId,
              entry: entry,
            );
          }
        }
      }
    } catch (_) {
      // Ignore malformed legacy payloads and continue startup.
    }

    await prefs.setBool(markerKey, true);
  }

  int _calculateStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) {
      return 0;
    }

    final normalizedDays = entries
        .map((entry) =>
            DateTime(entry.date.year, entry.date.month, entry.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final yesterdayOnly = todayOnly.subtract(const Duration(days: 1));

    DateTime? cursor;
    if (normalizedDays.contains(todayOnly)) {
      cursor = todayOnly;
    } else if (normalizedDays.contains(yesterdayOnly)) {
      cursor = yesterdayOnly;
    }

    if (cursor == null) {
      return 0;
    }

    var streak = 0;
    var dayCursor = cursor;
    while (normalizedDays.contains(dayCursor)) {
      streak += 1;
      dayCursor = dayCursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _biometricStorageKey(String userId) => 'journal_lock_enabled_$userId';

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }
}

class MoodProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<MoodEntry>>? _entriesSubscription;
  List<MoodEntry> _entries = [];
  String? _activeUserId;
  bool _isLoading = false;

  List<MoodEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  MoodEntry? getEntryForDate(DateTime date) {
    try {
      return _entries.firstWhere((entry) {
        return entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day;
      });
    } catch (_) {
      return null;
    }
  }

  CyclePrediction? get cyclePrediction => _calculateCyclePrediction();

  List<String> mostFrequentSymptoms({int limit = 5}) {
    final symptomCounts = <String, int>{};
    for (final entry in _entries) {
      for (final symptom in entry.symptoms) {
        symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
      }
    }

    final sorted = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((entry) => entry.key).toList();
  }

  Future<void> init([String? userId]) async {
    if (userId == null || userId.isEmpty) {
      _entries = [];
      _activeUserId = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_activeUserId == userId && _entriesSubscription != null) {
      return;
    }

    _isLoading = true;
    _activeUserId = userId;
    notifyListeners();

    await _migrateLegacyMoodEntriesIfNeeded(userId);

    await _entriesSubscription?.cancel();
    _entriesSubscription =
        _firestoreService.watchMoodEntries(userId).listen((incomingEntries) {
      _entries = incomingEntries..sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> logMood(MoodEntry entry) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not initialized for mood tracking.');
    }

    final now = DateTime.now();
    final resolvedEntry = MoodEntry(
      id: entry.id,
      mood: entry.mood,
      emoji: entry.emoji,
      note: entry.note,
      date: entry.date,
      createdAt: entry.createdAt,
      updatedAt: now,
      isPeriodDay: entry.isPeriodDay,
      painLevel: entry.painLevel,
      symptoms: entry.symptoms,
      flow: entry.flow,
    );

    await _firestoreService.saveMoodEntry(
      userId: userId,
      entry: resolvedEntry,
    );
  }

  Future<void> deleteEntry(String moodEntryId) async {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User session not initialized for mood tracking.');
    }

    await _firestoreService.deleteMoodEntry(
      userId: userId,
      moodEntryId: moodEntryId,
    );
  }

  CyclePrediction? _calculateCyclePrediction() {
    final periodDays = _entries
        .where((entry) => entry.isPeriodDay)
        .map((entry) =>
            DateTime(entry.date.year, entry.date.month, entry.date.day))
        .toSet()
        .toList()
      ..sort();

    if (periodDays.isEmpty) {
      return null;
    }

    final periodStarts = <DateTime>[];
    for (var index = 0; index < periodDays.length; index += 1) {
      final day = periodDays[index];
      if (index == 0) {
        periodStarts.add(day);
        continue;
      }
      final previousDay = periodDays[index - 1];
      final gap = day.difference(previousDay).inDays;
      if (gap > 1) {
        periodStarts.add(day);
      }
    }

    if (periodStarts.isEmpty) {
      return null;
    }

    final cycleLengths = <int>[];
    for (var i = 1; i < periodStarts.length; i += 1) {
      final days = periodStarts[i].difference(periodStarts[i - 1]).inDays;
      if (days >= 21 && days <= 40) {
        cycleLengths.add(days);
      }
    }

    final averageCycleLength = cycleLengths.isEmpty
        ? 28
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();

    final lastPeriodStart = periodStarts.last;
    final predictedNextPeriod =
        lastPeriodStart.add(Duration(days: averageCycleLength));

    final ovulationDay = predictedNextPeriod.subtract(const Duration(days: 14));
    final fertileWindowStart = ovulationDay.subtract(const Duration(days: 2));
    final fertileWindowEnd = ovulationDay.add(const Duration(days: 2));

    final confidence = cycleLengths.length >= 3
        ? 0.9
        : cycleLengths.length == 2
            ? 0.75
            : 0.5;

    return CyclePrediction(
      predictedNextPeriodStart: predictedNextPeriod,
      fertileWindowStart: fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd,
      averageCycleLengthDays: averageCycleLength,
      confidence: confidence,
    );
  }

  Future<void> clearSession() async {
    await _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _entries = [];
    _activeUserId = null;
    notifyListeners();
  }

  Future<void> _migrateLegacyMoodEntriesIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final markerKey = 'legacy_moods_migrated_$userId';
    if (prefs.getBool(markerKey) == true) {
      return;
    }

    final raw = prefs.getString('moods');
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(markerKey, true);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final entry = MoodEntry.fromMap(Map<String, dynamic>.from(item));
            await _firestoreService.saveMoodEntry(
              userId: userId,
              entry: entry,
            );
          }
        }
      }
    } catch (_) {
      // Ignore malformed legacy payloads and continue startup.
    }

    await prefs.setBool(markerKey, true);
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }
}

class SavedPostProvider extends ChangeNotifier {
  static const String _savedPostsKey = 'saved_posts';
  static const String _savedPostCollectionsKey = 'saved_post_collections';
  static const String defaultCollectionName = 'Saved';

  Set<String> _savedPostIds = {};
  Map<String, String> _collectionByPostId = {};

  Set<String> get savedPostIds => _savedPostIds;
  Map<String, String> get collectionByPostId =>
      Map<String, String>.unmodifiable(_collectionByPostId);

  List<String> get collections {
    final values = _collectionByPostId.values.toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!values.contains(defaultCollectionName)) {
      values.insert(0, defaultCollectionName);
    }
    return values;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_savedPostsKey);
    if (data != null) {
      _savedPostIds = data.toSet();
    }

    final rawCollections = prefs.getString(_savedPostCollectionsKey);
    if (rawCollections != null && rawCollections.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCollections);
        if (decoded is Map<String, dynamic>) {
          _collectionByPostId = decoded.map(
            (key, value) =>
                MapEntry(key, _sanitizeCollectionName(value?.toString())),
          );
        }
      } catch (_) {
        _collectionByPostId = {};
      }
    }

    _collectionByPostId.removeWhere((postId, _) => !_savedPostIds.contains(postId));
    for (final postId in _savedPostIds) {
      _collectionByPostId[postId] =
          _sanitizeCollectionName(_collectionByPostId[postId]);
    }

    await _save();
    notifyListeners();
  }

  Future<void> toggleSave(String postId) async {
    if (_savedPostIds.contains(postId)) {
      await removeSaved(postId);
    } else {
      await saveToCollection(
        postId: postId,
        collectionName: defaultCollectionName,
      );
    }
  }

  Future<void> saveToCollection({
    required String postId,
    required String collectionName,
  }) async {
    _savedPostIds.add(postId);
    _collectionByPostId[postId] = _sanitizeCollectionName(collectionName);
    await _save();
    notifyListeners();
  }

  Future<void> updateCollection({
    required String postId,
    required String collectionName,
  }) async {
    if (!_savedPostIds.contains(postId)) {
      return;
    }
    _collectionByPostId[postId] = _sanitizeCollectionName(collectionName);
    await _save();
    notifyListeners();
  }

  Future<void> removeSaved(String postId) async {
    _savedPostIds.remove(postId);
    _collectionByPostId.remove(postId);
    await _save();
    notifyListeners();
  }

  bool isSaved(String postId) => _savedPostIds.contains(postId);

  String collectionFor(String postId) =>
      _collectionByPostId[postId] ?? defaultCollectionName;

  String _sanitizeCollectionName(String? rawName) {
    final trimmed = rawName?.trim() ?? '';
    return trimmed.isEmpty ? defaultCollectionName : trimmed;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedPostsKey, _savedPostIds.toList());
    await prefs.setString(
      _savedPostCollectionsKey,
      jsonEncode(_collectionByPostId),
    );
  }
}

class UserProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<UserModel>>? _usersSubscription;
  List<UserModel> _users = [];

  List<UserModel> get users => _users;

  Future<void> init() async {
    await _usersSubscription?.cancel();
    _usersSubscription =
        _firestoreService.watchAllUsers().listen((incomingUsers) {
      _users = incomingUsers;
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    try {
      _users = await _firestoreService.getAllUsers();
      notifyListeners();
    } catch (_) {
      _users = [];
      notifyListeners();
    }
  }

  Future<void> addUser(UserModel user) async {
    try {
      final existingIdx =
          _users.indexWhere((candidate) => candidate.id == user.id);
      if (existingIdx != -1) {
        _users[existingIdx] = user;
        await _firestoreService.updateUser(user.id, {
          'username': user.username,
          'displayName': user.displayName,
          'bio': user.bio,
          'avatarUrl': user.avatarUrl,
          'email': user.email,
          'isPublic': user.isPublic,
          'followerIds': user.followerIds,
          'followingIds': user.followingIds,
          'pendingFollowRequests': user.pendingFollowRequests,
          'pronouns': user.pronouns,
          'website': user.website,
        });
      } else {
        await _firestoreService.createUser(user);
        _users.add(user);
      }
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  List<UserModel> searchUsers(String query) {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) {
      return _users.where((user) => user.isPublic).toList();
    }

    final matches = _users
        .where(
          (user) => matchesAnySearchField(
            fields: <String>[user.username, user.displayName, user.bio ?? ''],
            tokens: tokens,
          ),
        )
        .toList();

    // Keep public profiles first while still allowing private profile discovery.
    matches.sort((a, b) {
      if (a.isPublic == b.isPublic) {
        return a.username.compareTo(b.username);
      }
      return a.isPublic ? -1 : 1;
    });
    return matches;
  }

  UserModel? getUserById(String userId) =>
      _users.firstWhereOrNull((user) => user.id == userId);

  List<PostModel> getUserPosts(String userId, List<PostModel> allPosts) {
    final user = getUserById(userId);
    if (user == null || !user.isPublic) {
      return [];
    }
    return allPosts
        .where((post) => post.userId == userId && !post.isAnonymous)
        .toList();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }
}

extension UserListExt on List<UserModel> {
  UserModel? firstWhereOrNull(bool Function(UserModel) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }
}

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  List<NotificationModel> _notifications = [];

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> loadNotifications(String userId) async {
    await _notificationsSubscription?.cancel();
    _notificationsSubscription =
        _firestoreService.watchNotificationsForUser(userId).listen((incoming) {
      _notifications = incoming;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestoreService.markNotificationAsRead(notificationId);
      final idx = _notifications
          .indexWhere((notification) => notification.id == notificationId);
      if (idx != -1) {
        final current = _notifications[idx];
        _notifications[idx] = NotificationModel(
          id: current.id,
          toUserId: current.toUserId,
          fromUserId: current.fromUserId,
          type: current.type,
          postId: current.postId,
          pinId: current.pinId,
          isRead: true,
          createdAt: current.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<String> createNotification({
    required String toUserId,
    required String fromUserId,
    required NotificationType type,
    String? postId,
    String? pinId,
  }) async {
    try {
      return await _firestoreService.createNotification(
        toUserId: toUserId,
        fromUserId: fromUserId,
        type: type,
        postId: postId,
        pinId: pinId,
      );
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestoreService.deleteNotification(notificationId);
      _notifications
          .removeWhere((notification) => notification.id == notificationId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  Future<void> clearSession() async {
    await _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    _notifications = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final int _messagePageSize = 40;

  StreamSubscription<List<ChatModel>>? _chatsSubscription;
  final Map<String, StreamSubscription<List<ChatMessageModel>>>
      _messageSubscriptions = {};

  List<ChatModel> _chats = [];
  final Map<String, List<ChatMessageModel>> _messagesByChatId = {};
  final Map<String, DocumentSnapshot?> _messageCursorByChat = {};
  final Map<String, bool> _hasMoreMessagesByChat = {};
  final Map<String, bool> _isLoadingOlderByChat = {};
  final Map<String, DateTime> _lastReadAtByChat = {};

  String? _activeUserId;
  bool _isLoadingInbox = false;

  List<ChatModel> get chats => _chats;
  bool get isLoadingInbox => _isLoadingInbox;
  String? get activeUserId => _activeUserId;
  int get unreadCount => _chats.where(_isChatUnread).length;

  List<ChatMessageModel> messagesForChat(String chatId) =>
      _messagesByChatId[chatId] ?? const [];

  bool hasMoreMessages(String chatId) => _hasMoreMessagesByChat[chatId] ?? false;

  bool isLoadingOlderMessages(String chatId) =>
      _isLoadingOlderByChat[chatId] ?? false;

  bool isChatUnreadById(String chatId) {
    final chat = _chatById(chatId);
    if (chat == null) {
      return false;
    }
    return _isChatUnread(chat);
  }

  bool canMessageUser({
    required String currentUserId,
    required UserModel targetUser,
  }) {
    if (currentUserId == targetUser.id) {
      return false;
    }

    return targetUser.isPublic || targetUser.followerIds.contains(currentUserId);
  }

  bool isGroupChat(ChatModel chat) {
    return chat.isGroup;
  }

  String? otherParticipantId(ChatModel chat) {
    if (isGroupChat(chat)) {
      return null;
    }

    for (final participantId in chat.participantIds) {
      if (participantId != _activeUserId) {
        return participantId;
      }
    }
    return null;
  }

  Future<void> init(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    if (_activeUserId == userId && _chatsSubscription != null) {
      return;
    }

    await clearSession();
    _activeUserId = userId;
    _isLoadingInbox = true;
    await _loadReadState(userId);
    notifyListeners();

    _chatsSubscription =
        _firestoreService.watchChatsForUser(userId).listen((incomingChats) {
      _chats = incomingChats;
      _isLoadingInbox = false;
      notifyListeners();
    }, onError: (_) {
      _isLoadingInbox = false;
      notifyListeners();
    });
  }

  Future<String> ensureDirectChat(String otherUserId) async {
    final currentUserId = _activeUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Chat provider is not initialized.');
    }

    final chatId = await _firestoreService.ensureDirectChat(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    await openChat(chatId);
    return chatId;
  }

  Future<String> createGroupChat({
    required String groupName,
    required List<String> selectedUserIds,
  }) async {
    final currentUserId = _activeUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Chat provider is not initialized.');
    }

    final chatId = await _firestoreService.createGroupChat(
      currentUserId: currentUserId,
      groupName: groupName,
      participantIds: selectedUserIds,
    );
    await openChat(chatId);
    return chatId;
  }

  Future<void> openChat(String chatId) async {
    if (chatId.isEmpty) {
      return;
    }

    if (!_messagesByChatId.containsKey(chatId)) {
      await _loadInitialMessages(chatId);
    }

    if (!_messageSubscriptions.containsKey(chatId)) {
      _messageSubscriptions[chatId] =
          _firestoreService.watchMessages(chatId, limit: _messagePageSize).listen(
        (incomingMessages) {
          final existing = _messagesByChatId[chatId] ?? const [];
          _messagesByChatId[chatId] =
              _mergeMessages(existing: existing, incoming: incomingMessages);
          notifyListeners();
        },
      );
    }

    await markChatRead(chatId);
  }

  Future<void> _loadInitialMessages(String chatId) async {
    if (isLoadingOlderMessages(chatId)) {
      return;
    }

    _isLoadingOlderByChat[chatId] = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getMessagesPage(
        chatId: chatId,
        limit: _messagePageSize,
      );

      _messagesByChatId[chatId] = page.items;
      _messageCursorByChat[chatId] = page.lastDocument;
      _hasMoreMessagesByChat[chatId] = page.hasMore;
    } finally {
      _isLoadingOlderByChat[chatId] = false;
      notifyListeners();
    }
  }

  Future<void> loadOlderMessages(String chatId) async {
    if (chatId.isEmpty) {
      return;
    }

    if (isLoadingOlderMessages(chatId)) {
      return;
    }

    if (!hasMoreMessages(chatId)) {
      return;
    }

    final cursor = _messageCursorByChat[chatId];
    if (cursor == null) {
      _hasMoreMessagesByChat[chatId] = false;
      notifyListeners();
      return;
    }

    _isLoadingOlderByChat[chatId] = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getMessagesPage(
        chatId: chatId,
        startAfter: cursor,
        limit: _messagePageSize,
      );

      final existing = _messagesByChatId[chatId] ?? const [];
      _messagesByChatId[chatId] =
          _mergeMessages(existing: existing, incoming: page.items);
      _messageCursorByChat[chatId] = page.lastDocument;
      _hasMoreMessagesByChat[chatId] = page.hasMore;
    } finally {
      _isLoadingOlderByChat[chatId] = false;
      notifyListeners();
    }
  }

  Future<void> sendText({
    required String chatId,
    required String text,
  }) async {
    final senderId = _activeUserId;
    if (senderId == null || senderId.isEmpty) {
      throw Exception('Chat provider is not initialized.');
    }

    await _firestoreService.sendTextMessage(
      chatId: chatId,
      senderId: senderId,
      text: text,
    );
    await markChatRead(chatId);
  }

  Future<void> sharePost({
    required String chatId,
    required PostModel post,
  }) async {
    final senderId = _activeUserId;
    if (senderId == null || senderId.isEmpty) {
      throw Exception('Chat provider is not initialized.');
    }

    await _firestoreService.sendSharedPostMessage(
      chatId: chatId,
      senderId: senderId,
      post: post,
    );
    await markChatRead(chatId);
  }

  Future<void> markChatRead(
    String chatId, {
    DateTime? at,
  }) async {
    final chat = _chatById(chatId);
    final markTime = at ?? chat?.lastMessageAt ?? DateTime.now();
    final currentMark = _lastReadAtByChat[chatId];
    if (currentMark != null && !markTime.isAfter(currentMark)) {
      return;
    }

    _lastReadAtByChat[chatId] = markTime;
    notifyListeners();
    await _persistReadState();
  }

  Future<void> markAllAsRead() async {
    var changed = false;
    for (final chat in _chats) {
      if (!_isChatUnread(chat)) {
        continue;
      }
      _lastReadAtByChat[chat.id] = chat.lastMessageAt;
      changed = true;
    }

    if (!changed) {
      return;
    }

    notifyListeners();
    await _persistReadState();
  }

  bool _isChatUnread(ChatModel chat) {
    final currentUserId = _activeUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    if (chat.lastMessageSenderId == null ||
        chat.lastMessageSenderId == currentUserId) {
      return false;
    }

    final readAt = _lastReadAtByChat[chat.id];
    if (readAt == null) {
      return true;
    }
    return chat.lastMessageAt.isAfter(readAt);
  }

  List<ChatMessageModel> _mergeMessages({
    required List<ChatMessageModel> existing,
    required List<ChatMessageModel> incoming,
  }) {
    final deduped = <String, ChatMessageModel>{
      for (final message in existing) message.id: message,
      for (final message in incoming) message.id: message,
    };

    final merged = deduped.values.toList();
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  ChatModel? _chatById(String chatId) {
    for (final chat in _chats) {
      if (chat.id == chatId) {
        return chat;
      }
    }
    return null;
  }

  Future<void> _loadReadState(String userId) async {
    _lastReadAtByChat.clear();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('dm_last_read_$userId');
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final parsed = DateTime.tryParse(entry.value.toString());
          if (parsed != null) {
            _lastReadAtByChat[entry.key] = parsed;
          }
        }
      }
    } catch (_) {
      // Ignore malformed persisted read state.
    }
  }

  Future<void> _persistReadState() async {
    final currentUserId = _activeUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    final payload = <String, String>{
      for (final entry in _lastReadAtByChat.entries)
        entry.key: entry.value.toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dm_last_read_$currentUserId', jsonEncode(payload));
  }

  Future<void> clearSession() async {
    await _chatsSubscription?.cancel();
    _chatsSubscription = null;

    for (final subscription in _messageSubscriptions.values) {
      await subscription.cancel();
    }
    _messageSubscriptions.clear();

    _chats = [];
    _messagesByChatId.clear();
    _messageCursorByChat.clear();
    _hasMoreMessagesByChat.clear();
    _isLoadingOlderByChat.clear();
    _lastReadAtByChat.clear();
    _activeUserId = null;
    _isLoadingInbox = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    for (final subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    super.dispose();
  }
}

class CommentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  final Map<String, List<CommentModel>> _commentsByPost = {};

  List<CommentModel> getCommentsForPost(String postId) =>
      _commentsByPost[postId] ?? [];

  Future<void> loadCommentsForPost(String postId) async {
    try {
      _commentsByPost[postId] =
          await _firestoreService.getCommentsForPost(postId);
      notifyListeners();
    } catch (_) {
      _commentsByPost[postId] = [];
      notifyListeners();
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
    bool isAnonymous = false,
  }) async {
    try {
      await _firestoreService.createComment(
        postId: postId,
        userId: userId,
        text: text,
        parentCommentId: parentCommentId,
        isAnonymous: isAnonymous,
      );
      await loadCommentsForPost(postId);
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _firestoreService.deleteComment(
          postId: postId, commentId: commentId);
      if (_commentsByPost.containsKey(postId)) {
        _commentsByPost[postId]!
            .removeWhere((comment) => comment.id == commentId);
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> likeComment(
      String postId, String commentId, String userId) async {
    try {
      if (!_commentsByPost.containsKey(postId)) {
        return;
      }

      final idx = _commentsByPost[postId]!
          .indexWhere((comment) => comment.id == commentId);
      if (idx == -1) {
        return;
      }

      final comment = _commentsByPost[postId]![idx];
      if (comment.likedByIds.contains(userId)) {
        return;
      }

      await _firestoreService.likeComment(
        postId: postId,
        commentId: commentId,
        userId: userId,
      );

      _commentsByPost[postId]![idx] = CommentModel(
        id: comment.id,
        postId: comment.postId,
        userId: comment.userId,
        text: comment.text,
        parentCommentId: comment.parentCommentId,
        createdAt: comment.createdAt,
        isAnonymous: comment.isAnonymous,
        likedByIds: [...comment.likedByIds, userId],
      );
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  Future<void> unlikeComment(
      String postId, String commentId, String userId) async {
    try {
      if (!_commentsByPost.containsKey(postId)) {
        return;
      }

      final idx = _commentsByPost[postId]!
          .indexWhere((comment) => comment.id == commentId);
      if (idx == -1) {
        return;
      }

      final comment = _commentsByPost[postId]![idx];
      if (!comment.likedByIds.contains(userId)) {
        return;
      }

      await _firestoreService.unlikeComment(
        postId: postId,
        commentId: commentId,
        userId: userId,
      );

      _commentsByPost[postId]![idx] = CommentModel(
        id: comment.id,
        postId: comment.postId,
        userId: comment.userId,
        text: comment.text,
        parentCommentId: comment.parentCommentId,
        createdAt: comment.createdAt,
        isAnonymous: comment.isAnonymous,
        likedByIds: comment.likedByIds.where((id) => id != userId).toList(),
      );
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to unlike comment: $e');
    }
  }
}

class PinProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  static const String _savedPinCollectionsKeyPrefix =
      'saved_pin_collections_';
  static const String defaultSavedPinCollectionName = 'Saved';

  final int _pageSize = 20;

  List<PinModel> _pins = [];
  List<PinModel> _userPins = [];
  List<Map<String, dynamic>> _boards = [];

  DocumentSnapshot? _discoverCursor;
  bool _hasMoreDiscoverPins = true;
  bool _isLoadingDiscoverPins = false;

  String? _userPinsOwner;
  DocumentSnapshot? _userPinsCursor;
  bool _hasMoreUserPins = true;
  bool _isLoadingUserPins = false;

  String? _savedPinCollectionsUserId;
  Map<String, String> _savedPinCollectionByPinId = {};

  List<PinModel> get pins => _pins;
  List<PinModel> get userPins => _userPins;
  List<Map<String, dynamic>> get boards => _boards;
  bool get hasMoreDiscoverPins => _hasMoreDiscoverPins;
  bool get isLoadingDiscoverPins => _isLoadingDiscoverPins;
  String? get savedPinCollectionsUserId => _savedPinCollectionsUserId;

  List<String> get savedPinCollections {
    final values = _savedPinCollectionByPinId.values.toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!values.contains(defaultSavedPinCollectionName)) {
      values.insert(0, defaultSavedPinCollectionName);
    }
    return values;
  }

  String savedPinCollectionFor(String pinId) =>
      _savedPinCollectionByPinId[pinId] ?? defaultSavedPinCollectionName;

  Future<void> init() async {
    await reloadPublicPins(reset: true);
  }

  Future<void> loadSavedPinCollections(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    if (_savedPinCollectionsUserId == userId) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_savedPinCollectionsKeyPrefix$userId');
    _savedPinCollectionByPinId = {};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _savedPinCollectionByPinId = decoded.map(
            (key, value) => MapEntry(
              key,
              _sanitizeSavedPinCollectionName(value?.toString()),
            ),
          );
        }
      } catch (_) {
        _savedPinCollectionByPinId = {};
      }
    }

    _savedPinCollectionsUserId = userId;
    notifyListeners();
  }

  Future<void> reloadPublicPins({bool reset = false}) async {
    if (_isLoadingDiscoverPins) {
      return;
    }

    if (reset) {
      _discoverCursor = null;
      _hasMoreDiscoverPins = true;
      _pins = [];
      notifyListeners();
    }

    if (!_hasMoreDiscoverPins) {
      return;
    }

    _isLoadingDiscoverPins = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getPublicPinsPage(
        startAfter: _discoverCursor,
        limit: _pageSize,
      );

      _discoverCursor = page.lastDocument;
      _hasMoreDiscoverPins = page.hasMore;
      final incoming =
          page.items.map((data) => PinModel.fromMap(data)).toList();
      _pins = _mergePins(existing: _pins, incoming: incoming);
    } finally {
      _isLoadingDiscoverPins = false;
      notifyListeners();
    }
  }

  Future<List<PinModel>> loadMorePublicPins() async {
    final before = _pins.length;
    await reloadPublicPins(reset: false);
    if (_pins.length <= before) {
      return [];
    }
    return _pins.sublist(before);
  }

  Future<void> loadUserPins(
    String userId, {
    bool reset = true,
  }) async {
    if (_isLoadingUserPins) {
      return;
    }

    if (reset || _userPinsOwner != userId) {
      _userPinsOwner = userId;
      _userPinsCursor = null;
      _hasMoreUserPins = true;
      _userPins = [];
      notifyListeners();
    }

    if (!_hasMoreUserPins) {
      return;
    }

    _isLoadingUserPins = true;
    notifyListeners();

    try {
      final page = await _firestoreService.getUserPinsPage(
        userId: userId,
        startAfter: _userPinsCursor,
        limit: _pageSize,
      );

      _userPinsCursor = page.lastDocument;
      _hasMoreUserPins = page.hasMore;

      final incoming =
          page.items.map((item) => PinModel.fromMap(item)).toList();
      _userPins = _mergePins(existing: _userPins, incoming: incoming);
      _pins = _mergePins(existing: _pins, incoming: incoming);
    } finally {
      _isLoadingUserPins = false;
      notifyListeners();
    }
  }

  Future<void> loadUserBoards(String userId) async {
    try {
      _boards = await _firestoreService.getUserBoards(userId);
      notifyListeners();
    } catch (_) {
      _boards = [];
      notifyListeners();
    }
  }

  Future<String?> createPin({
    required String userId,
    required String title,
    required String boardId,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageFileName,
    String? description,
    bool isPublic = true,
    List<String> tags = const [],
  }) async {
    try {
      final pinId = await _firestoreService.createPin(
        userId: userId,
        title: title,
        boardId: boardId,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        description: description,
        isPublic: isPublic,
        tags: tags,
      );

      await loadUserPins(userId, reset: true);
      await loadUserBoards(userId);
      await reloadPublicPins(reset: true);
      return pinId;
    } catch (e) {
      throw Exception('Failed to create pin: $e');
    }
  }

  Future<PinModel?> fetchPinById(String pinId) async {
    try {
      final pinMap = await _firestoreService.getPin(pinId);
      if (pinMap == null) {
        return null;
      }

      final pin = PinModel.fromMap(pinMap);
      _upsertPin(pin);
      return pin;
    } catch (e) {
      throw Exception('Failed to fetch pin: $e');
    }
  }

  Future<String?> createBoard({
    required String userId,
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      final boardId = await _firestoreService.createBoard(
        userId: userId,
        name: name,
        description: description,
        isPublic: isPublic,
      );
      await loadUserBoards(userId);
      return boardId;
    } catch (e) {
      throw Exception('Failed to create board: $e');
    }
  }

  Future<void> likePin(String pinId, String userId) async {
    try {
      await _firestoreService.updatePin(pinId, {
        'likedByIds': FieldValue.arrayUnion([userId]),
      });
      await _refreshPin(pinId);
    } catch (e) {
      throw Exception('Failed to like pin: $e');
    }
  }

  Future<void> unlikePin(String pinId, String userId) async {
    try {
      await _firestoreService.updatePin(pinId, {
        'likedByIds': FieldValue.arrayRemove([userId]),
      });
      await _refreshPin(pinId);
    } catch (e) {
      throw Exception('Failed to unlike pin: $e');
    }
  }

  Future<void> savePin(
    String pinId,
    String userId, {
    String collectionName = defaultSavedPinCollectionName,
  }) async {
    try {
      await loadSavedPinCollections(userId);
      await _firestoreService.updatePin(pinId, {
        'savedByIds': FieldValue.arrayUnion([userId]),
      });

      _savedPinCollectionByPinId[pinId] =
          _sanitizeSavedPinCollectionName(collectionName);
      await _persistSavedPinCollections(userId);
      await _refreshPin(pinId);
    } catch (e) {
      throw Exception('Failed to save pin: $e');
    }
  }

  Future<void> updateSavedPinCollection({
    required String pinId,
    required String userId,
    required String collectionName,
  }) async {
    await loadSavedPinCollections(userId);
    _savedPinCollectionByPinId[pinId] =
        _sanitizeSavedPinCollectionName(collectionName);
    await _persistSavedPinCollections(userId);
    notifyListeners();
  }

  Future<void> unsavePin(String pinId, String userId) async {
    try {
      await loadSavedPinCollections(userId);
      await _firestoreService.updatePin(pinId, {
        'savedByIds': FieldValue.arrayRemove([userId]),
      });

      _savedPinCollectionByPinId.remove(pinId);
      await _persistSavedPinCollections(userId);
      await _refreshPin(pinId);
    } catch (e) {
      throw Exception('Failed to unsave pin: $e');
    }
  }

  String _sanitizeSavedPinCollectionName(String? rawName) {
    final trimmed = rawName?.trim() ?? '';
    return trimmed.isEmpty ? defaultSavedPinCollectionName : trimmed;
  }

  Future<void> _persistSavedPinCollections(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_savedPinCollectionsKeyPrefix$userId',
      jsonEncode(_savedPinCollectionByPinId),
    );
  }

  Future<void> deletePin(String pinId) async {
    try {
      await _firestoreService.deletePin(pinId);
      _pins.removeWhere((pin) => pin.id == pinId);
      _userPins.removeWhere((pin) => pin.id == pinId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete pin: $e');
    }
  }

  Future<void> deleteBoard(String boardId) async {
    try {
      await _firestoreService.deleteBoard(boardId);
      _boards.removeWhere((board) => board['id'] == boardId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete board: $e');
    }
  }

  Future<void> _refreshPin(String pinId) async {
    final pinMap = await _firestoreService.getPin(pinId);
    if (pinMap == null) {
      _pins.removeWhere((pin) => pin.id == pinId);
      _userPins.removeWhere((pin) => pin.id == pinId);
      notifyListeners();
      return;
    }

    final refreshed = PinModel.fromMap(pinMap);
    _upsertPin(refreshed);
  }

  void _upsertPin(PinModel pin) {
    final pinIndex = _pins.indexWhere((candidate) => candidate.id == pin.id);
    if (pinIndex == -1) {
      _pins.add(pin);
    } else {
      _pins[pinIndex] = pin;
    }

    final userPinIndex =
        _userPins.indexWhere((candidate) => candidate.id == pin.id);
    if (userPinIndex != -1) {
      _userPins[userPinIndex] = pin;
    }

    _pins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _userPins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  List<PinModel> _mergePins({
    required List<PinModel> existing,
    required List<PinModel> incoming,
  }) {
    final deduped = <String, PinModel>{
      for (final pin in existing) pin.id: pin,
      for (final pin in incoming) pin.id: pin,
    };
    final merged = deduped.values.toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}

class FollowProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Future<List<String>> getFollowers(String userId) async {
    try {
      final user = await _firestoreService.getUser(userId);
      return user?.followerIds ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getFollowing(String userId) async {
    try {
      final user = await _firestoreService.getUser(userId);
      return user?.followingIds ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getPendingRequests(String userId) async {
    try {
      final user = await _firestoreService.getUser(userId);
      return user?.pendingFollowRequests ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final user = await _firestoreService.getUser(currentUserId);
      return user?.followingIds.contains(targetUserId) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception('Users cannot follow themselves.');
      }

      await _firestoreService.updateUser(currentUserId, {
        'followingIds': FieldValue.arrayUnion([targetUserId]),
      });

      await _firestoreService.updateUser(targetUserId, {
        'pendingFollowRequests': FieldValue.arrayRemove([currentUserId]),
        'followerIds': FieldValue.arrayUnion([currentUserId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  Future<void> sendFollowRequest({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception('Users cannot follow themselves.');
      }

      await _firestoreService.updateUser(targetUserId, {
        'pendingFollowRequests': FieldValue.arrayUnion([currentUserId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to send follow request: $e');
    }
  }

  Future<void> cancelFollowRequest({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception('Users cannot cancel a self-request.');
      }

      await _firestoreService.updateUser(targetUserId, {
        'pendingFollowRequests': FieldValue.arrayRemove([currentUserId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to cancel follow request: $e');
    }
  }

  Future<void> acceptFollowRequest({
    required String userId,
    required String followerId,
  }) async {
    try {
      if (userId == followerId) {
        throw Exception('Users cannot approve self-follow.');
      }

      await _firestoreService.updateUser(userId, {
        'pendingFollowRequests': FieldValue.arrayRemove([followerId]),
        'followerIds': FieldValue.arrayUnion([followerId]),
      });

      await _firestoreService.updateUser(followerId, {
        'followingIds': FieldValue.arrayUnion([userId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to accept follow request: $e');
    }
  }

  Future<void> declineFollowRequest({
    required String userId,
    required String followerId,
  }) async {
    try {
      await _firestoreService.updateUser(userId, {
        'pendingFollowRequests': FieldValue.arrayRemove([followerId]),
      });
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to decline follow request: $e');
    }
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception('Users cannot unfollow themselves.');
      }

      await _firestoreService.updateUser(currentUserId, {
        'followingIds': FieldValue.arrayRemove([targetUserId]),
      });

      await _firestoreService.updateUser(targetUserId, {
        'followerIds': FieldValue.arrayRemove([currentUserId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  Future<void> removeFollower({
    required String userId,
    required String followerId,
  }) async {
    try {
      if (userId == followerId) {
        throw Exception('Cannot remove self as follower.');
      }

      await _firestoreService.updateUser(userId, {
        'followerIds': FieldValue.arrayRemove([followerId]),
        'pendingFollowRequests': FieldValue.arrayRemove([followerId]),
      });

      await _firestoreService.updateUser(followerId, {
        'followingIds': FieldValue.arrayRemove([userId]),
      });

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to remove follower: $e');
    }
  }
}
