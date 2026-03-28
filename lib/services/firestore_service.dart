import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import '../models/models.dart';
import 'external_image_host_service.dart';

class FirestorePage<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const FirestorePage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

class FirestoreService {
  static const double _unifiedMediaAspectRatio = 4 / 5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExternalImageHostService _externalImageHostService =
      ExternalImageHostService();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> get _pins =>
      _firestore.collection('pins');
  CollectionReference<Map<String, dynamic>> get _boards =>
      _firestore.collection('boards');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _journalRef(String userId) =>
      _users.doc(userId).collection('journal_entries');

  CollectionReference<Map<String, dynamic>> _moodRef(String userId) =>
      _users.doc(userId).collection('mood_entries');

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chats.doc(chatId).collection('messages');

  // ========== USERS ==========

  Future<void> createUser(UserModel user) async {
    try {
      await _users.doc(user.id).set({
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'bio': user.bio,
        'avatarUrl': user.avatarUrl,
        'email': user.email,
        'createdAt': Timestamp.fromDate(user.createdAt),
        'isPublic': user.isPublic,
        'followerIds': user.followerIds,
        'followingIds': user.followingIds,
        'pendingFollowRequests': user.pendingFollowRequests,
        'pronouns': user.pronouns,
        'website': user.website,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot =
          await _users.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map(_userFromFirestore).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Stream<List<UserModel>> watchAllUsers({int limit = 500}) {
    return _users
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_userFromFirestore).toList());
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (doc.exists) {
        return _userFromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Stream<UserModel?> watchUser(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _userFromFirestore(doc);
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _users.doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<String?> uploadUserAvatar({
    required String userId,
    required String? imagePathOrUrl,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    return _maybeUploadImage(
      imagePathOrUrl: imagePathOrUrl,
      imageBytes: imageBytes,
      imageFileName: imageFileName,
      folder: 'avatars',
      userId: userId,
      objectId: userId,
      forcedAspectRatio: null,
    );
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final query =
          await _users.where('username', isEqualTo: username).limit(1).get();
      if (query.docs.isNotEmpty) {
        return _userFromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by username: $e');
    }
  }

  // ========== POSTS ==========

  Future<String> createPost({
    required String userId,
    required String caption,
    String? imageUrl,
    Uint8List? imageBytes,
    String? imageFileName,
    bool isAnonymous = false,
    List<String> tags = const [],
  }) async {
    try {
      final postRef = _posts.doc();
      final resolvedImageUrl = await _maybeUploadImage(
        imagePathOrUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        folder: 'posts',
        userId: userId,
        objectId: postRef.id,
        forcedAspectRatio: _unifiedMediaAspectRatio,
      );

      await postRef.set({
        'id': postRef.id,
        'userId': userId,
        'caption': caption,
        'imageUrl': resolvedImageUrl,
        'isAnonymous': isAnonymous,
        'likedByIds': <String>[],
        'commentCount': 0,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'tags': tags,
        'visibility': 'public',
      });
      return postRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _posts.doc(postId).get();
      if (doc.exists) {
        return _postFromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get post: $e');
    }
  }

  Stream<PostModel?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _postFromFirestore(doc);
    });
  }

  Future<FirestorePage<PostModel>> getFeedPostsPage({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _posts.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map(_postFromFirestore).toList();

      return FirestorePage<PostModel>(
        items: posts,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to get feed posts page: $e');
    }
  }

  Future<FirestorePage<PostModel>> getPublicPostsPage({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _posts.where('isAnonymous', isEqualTo: false).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map(_postFromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return FirestorePage<PostModel>(
        items: posts,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to get public posts page: $e');
    }
  }

  Future<FirestorePage<PostModel>> getAnonymousPostsPage({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _posts.where('isAnonymous', isEqualTo: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map(_postFromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return FirestorePage<PostModel>(
        items: posts,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to get anonymous posts page: $e');
    }
  }

  Future<FirestorePage<PostModel>> getUserPostsPage({
    required String userId,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _posts.where('userId', isEqualTo: userId).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map(_postFromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return FirestorePage<PostModel>(
        items: posts,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to get user posts page: $e');
    }
  }

  Future<List<PostModel>> getPublicPosts({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    final page = await getPublicPostsPage(startAfter: startAfter, limit: limit);
    return page.items;
  }

  Future<List<PostModel>> getAnonymousPosts({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    final page =
        await getAnonymousPostsPage(startAfter: startAfter, limit: limit);
    return page.items;
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final page = await getUserPostsPage(userId: userId, limit: 200);
    return page.items;
  }

  Future<List<PostModel>> getFollowingPosts({
    required List<String> followingIds,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      if (followingIds.isEmpty) {
        return [];
      }

      final chunks = _chunkIds(followingIds, 10);
      final allPosts = <PostModel>[];

      for (final chunk in chunks) {
        Query<Map<String, dynamic>> query =
            _posts.where('userId', whereIn: chunk).limit(limit);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        final snapshot = await query.get();
        allPosts.addAll(snapshot.docs.map(_postFromFirestore));
      }

      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allPosts.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get following posts: $e');
    }
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    try {
      await _posts.doc(postId).update({
        ...data,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _posts.doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      await _posts.doc(postId).update({
        'likedByIds': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to like post: $e');
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _posts.doc(postId).update({
        'likedByIds': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to unlike post: $e');
    }
  }

  // ========== PINS ==========

  Future<String> createPin({
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
      final pinRef = _pins.doc();
      final resolvedImageUrl = await _maybeUploadImage(
        imagePathOrUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        folder: 'pins',
        userId: userId,
        objectId: pinRef.id,
        forcedAspectRatio: _unifiedMediaAspectRatio,
      );

      await pinRef.set({
        'id': pinRef.id,
        'userId': userId,
        'title': title,
        'boardId': boardId,
        'imageUrl': resolvedImageUrl,
        'description': description,
        'isPublic': isPublic,
        'likedByIds': <String>[],
        'savedByIds': <String>[],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'tags': tags,
      });
      return pinRef.id;
    } catch (e) {
      throw Exception('Failed to create pin: $e');
    }
  }

  Future<Map<String, dynamic>?> getPin(String pinId) async {
    try {
      final doc = await _pins.doc(pinId).get();
      if (!doc.exists) {
        return null;
      }
      return {
        'id': doc.id,
        ...?doc.data(),
      };
    } catch (e) {
      throw Exception('Failed to get pin: $e');
    }
  }

  Future<FirestorePage<Map<String, dynamic>>> getPublicPinsPage({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _pins.where('isPublic', isEqualTo: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final pins =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
            ..sort((a, b) {
              final aDate = _readDynamicDate(a['createdAt']);
              final bDate = _readDynamicDate(b['createdAt']);
              return bDate.compareTo(aDate);
            });

      return FirestorePage<Map<String, dynamic>>(
        items: pins,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to get public pins page: $e');
    }
  }

  Future<FirestorePage<Map<String, dynamic>>> getUserPinsPage({
    required String userId,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _pins.where('userId', isEqualTo: userId).get();
      final pins =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
            ..sort((a, b) {
              final aDate = _readDynamicDate(a['createdAt']);
              final bDate = _readDynamicDate(b['createdAt']);
              return bDate.compareTo(aDate);
            });

      return FirestorePage<Map<String, dynamic>>(
        items: pins.take(limit).toList(),
        lastDocument: null,
        hasMore: false,
      );
    } catch (e) {
      throw Exception('Failed to get user pins page: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPublicPins({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    final page = await getPublicPinsPage(startAfter: startAfter, limit: limit);
    return page.items;
  }

  Future<List<Map<String, dynamic>>> getBoardPins(String boardId) async {
    try {
      final snapshot = await _pins.where('boardId', isEqualTo: boardId).get();
      final pins =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
            ..sort((a, b) {
              final aDate = _readDynamicDate(a['createdAt']);
              final bDate = _readDynamicDate(b['createdAt']);
              return bDate.compareTo(aDate);
            });
      return pins;
    } catch (e) {
      throw Exception('Failed to get board pins: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserPins(
    String userId, {
    DocumentSnapshot? startAfter,
    int limit = 50,
  }) async {
    final page = await getUserPinsPage(
      userId: userId,
      startAfter: startAfter,
      limit: limit,
    );
    return page.items;
  }

  Future<void> updatePin(String pinId, Map<String, dynamic> data) async {
    try {
      await _pins.doc(pinId).update({
        ...data,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update pin: $e');
    }
  }

  Future<void> deletePin(String pinId) async {
    try {
      await _pins.doc(pinId).delete();
    } catch (e) {
      throw Exception('Failed to delete pin: $e');
    }
  }

  // ========== BOARDS ==========

  Future<String> createBoard({
    required String userId,
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      final doc = await _boards.add({
        'userId': userId,
        'name': name,
        'description': description,
        'isPublic': isPublic,
        'coverImageUrl': null,
        'pinIds': <String>[],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      return doc.id;
    } catch (e) {
      throw Exception('Failed to create board: $e');
    }
  }

  Future<Map<String, dynamic>?> getBoard(String boardId) async {
    try {
      final doc = await _boards.doc(boardId).get();
      if (!doc.exists) {
        return null;
      }
      return {
        'id': doc.id,
        ...?doc.data(),
      };
    } catch (e) {
      throw Exception('Failed to get board: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserBoards(String userId) async {
    try {
      final snapshot = await _boards.where('userId', isEqualTo: userId).get();
      final boards =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
            ..sort((a, b) {
              final aDate = _readDynamicDate(a['createdAt']);
              final bDate = _readDynamicDate(b['createdAt']);
              return bDate.compareTo(aDate);
            });
      return boards;
    } catch (e) {
      throw Exception('Failed to get user boards: $e');
    }
  }

  Future<void> updateBoard(String boardId, Map<String, dynamic> data) async {
    try {
      await _boards.doc(boardId).update({
        ...data,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update board: $e');
    }
  }

  Future<void> deleteBoard(String boardId) async {
    try {
      await _boards.doc(boardId).delete();
    } catch (e) {
      throw Exception('Failed to delete board: $e');
    }
  }

  // ========== NOTIFICATIONS ==========

  Future<String> createNotification({
    required String toUserId,
    required String fromUserId,
    required NotificationType type,
    String? postId,
    String? pinId,
  }) async {
    try {
      final ref = _notifications.doc();
      await ref.set({
        'id': ref.id,
        'toUserId': toUserId,
        'fromUserId': fromUserId,
        'type': type.toString().split('.').last,
        'postId': postId,
        'pinId': pinId,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
      return ref.id;
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  Future<List<NotificationModel>> getNotificationsForUser(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _notifications
          .where('toUserId', isEqualTo: userId)
          .limit(limit)
          .get();

      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          toUserId: data['toUserId'] as String,
          fromUserId: data['fromUserId'] as String,
          type: NotificationType.values.firstWhere(
            (t) => t.toString().split('.').last == data['type'],
            orElse: () => NotificationType.like,
          ),
          postId: data['postId'] as String?,
          pinId: data['pinId'] as String?,
          isRead: data['isRead'] as bool? ?? false,
          createdAt: _readDate(data, 'createdAt'),
        );
      }).toList();

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  Stream<List<NotificationModel>> watchNotificationsForUser(
    String userId, {
    int limit = 200,
  }) {
    return _notifications
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          toUserId: data['toUserId'] as String,
          fromUserId: data['fromUserId'] as String,
          type: NotificationType.values.firstWhere(
            (t) => t.toString().split('.').last == data['type'],
            orElse: () => NotificationType.like,
          ),
          postId: data['postId'] as String?,
          pinId: data['pinId'] as String?,
          isRead: data['isRead'] as bool? ?? false,
          createdAt: _readDate(data, 'createdAt'),
        );
      }).toList();

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (notifications.length > limit) {
        return notifications.take(limit).toList();
      }
      return notifications;
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notifications.doc(notificationId).update({'isRead': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notifications.doc(notificationId).delete();
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  // ========== DIRECT MESSAGES ==========

  String buildDirectChatId({
    required String userA,
    required String userB,
  }) {
    if (userA.trim().isEmpty || userB.trim().isEmpty) {
      throw Exception('Direct chat requires two valid user ids.');
    }

    if (userA == userB) {
      throw Exception('Cannot create a direct chat with self.');
    }

    final participants = [userA, userB]..sort();
    return participants.join('_');
  }

  Future<String> ensureDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final chatId = buildDirectChatId(
        userA: currentUserId,
        userB: otherUserId,
      );
      final chatRef = _chats.doc(chatId);

      final participants = [currentUserId, otherUserId]..sort();
      final createPayload = {
        'id': chatId,
        'participantIds': participants,
        'lastMessageText': 'Start chatting',
        'lastMessageSenderId': currentUserId,
        'lastMessageType': ChatMessageType.text.toString().split('.').last,
        'lastSharedPostId': null,
        'lastSharedPostCaption': null,
        'lastSharedPostImageUrl': null,
        'lastMessageAt': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      final touchPayload = {
        'lastMessageText': 'Start chatting',
        'lastMessageSenderId': currentUserId,
        'lastMessageType': ChatMessageType.text.toString().split('.').last,
        'lastSharedPostId': null,
        'lastSharedPostCaption': null,
        'lastSharedPostImageUrl': null,
        'lastMessageAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      try {
        // For a new chat, this satisfies create rules and succeeds.
        await chatRef.set(createPayload);
      } on FirebaseException catch (firebaseError) {
        try {
          // If chat already exists, fall back to merge update with only
          // fields allowed by update rules.
          await chatRef.set(touchPayload, SetOptions(merge: true));
        } on FirebaseException catch (mergeError) {
          if (firebaseError.code == 'permission-denied' ||
              mergeError.code == 'permission-denied') {
            throw Exception(
              'Missing Firestore permission for chats. Deploy latest firestore.rules and ensure user is signed in.',
            );
          }

          throw Exception(
            'Firestore chat creation/open failed (${mergeError.code}): ${mergeError.message ?? firebaseError.message ?? 'Unknown Firestore error'}',
          );
        }
      }

      return chatId;
    } on FirebaseException catch (firebaseError) {
      if (firebaseError.code == 'permission-denied') {
        throw Exception(
          'Missing Firestore permission for chats. Deploy latest firestore.rules and ensure user is signed in.',
        );
      }

      throw Exception(
        'Failed to ensure direct chat (${firebaseError.code}): ${firebaseError.message ?? 'Unknown Firestore error'}',
      );
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('Dart exception thrown from converted Future')) {
        throw Exception(
          'Chat creation failed on web. This usually means chat Firestore rules are not deployed yet. Run: firebase deploy --only firestore:rules',
        );
      }
      throw Exception('Failed to ensure direct chat: $e');
    }
  }

  Stream<List<ChatModel>> watchChatsForUser(
    String userId, {
    int limit = 300,
  }) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs.map(_chatFromFirestore).toList();
      chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return chats;
    });
  }

  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await _chats.doc(chatId).get();
      if (!doc.exists) {
        return null;
      }
      return _chatFromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch chat: $e');
    }
  }

  Stream<List<ChatMessageModel>> watchMessages(
    String chatId, {
    int limit = 40,
  }) {
    return _messagesRef(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final messages =
          snapshot.docs.map((doc) => _chatMessageFromFirestore(chatId, doc)).toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    });
  }

  Future<FirestorePage<ChatMessageModel>> getMessagesPage({
    required String chatId,
    DocumentSnapshot? startAfter,
    int limit = 40,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _messagesRef(chatId).orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final messages = snapshot.docs
          .map((doc) => _chatMessageFromFirestore(chatId, doc))
          .toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return FirestorePage<ChatMessageModel>(
        items: messages,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == limit,
      );
    } catch (e) {
      throw Exception('Failed to fetch messages page: $e');
    }
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    try {
      await _sendMessageInternal(
        chatId: chatId,
        senderId: senderId,
        type: ChatMessageType.text,
        previewText: trimmed,
        text: trimmed,
      );
    } catch (e) {
      throw Exception('Failed to send text message: $e');
    }
  }

  Future<void> sendSharedPostMessage({
    required String chatId,
    required String senderId,
    required PostModel post,
  }) async {
    try {
      final caption = post.caption.trim();
      final preview = caption.isEmpty
          ? 'Shared a post'
          : 'Shared post: ${caption.length > 40 ? '${caption.substring(0, 40)}...' : caption}';

      await _sendMessageInternal(
        chatId: chatId,
        senderId: senderId,
        type: ChatMessageType.sharedPost,
        previewText: preview,
        sharedPostId: post.id,
        sharedPostCaption: post.caption,
        sharedPostImageUrl: post.imageUrl,
        sharedPostAuthorId: post.userId,
      );
    } catch (e) {
      throw Exception('Failed to share post in chat: $e');
    }
  }

  Future<void> _sendMessageInternal({
    required String chatId,
    required String senderId,
    required ChatMessageType type,
    required String previewText,
    String? text,
    String? sharedPostId,
    String? sharedPostCaption,
    String? sharedPostImageUrl,
    String? sharedPostAuthorId,
  }) async {
    final messageRef = _messagesRef(chatId).doc();
    final chatRef = _chats.doc(chatId);
    final now = Timestamp.now();

    final messagePayload = <String, dynamic>{
      'id': messageRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'type': type.toString().split('.').last,
      'text': text,
      'sharedPostId': sharedPostId,
      'sharedPostCaption': sharedPostCaption,
      'sharedPostImageUrl': sharedPostImageUrl,
      'sharedPostAuthorId': sharedPostAuthorId,
      'createdAt': now,
    };

    final batch = _firestore.batch();
    batch.set(messageRef, messagePayload);
    batch.set(
      chatRef,
      {
        'id': chatId,
        'lastMessageText': previewText,
        'lastMessageSenderId': senderId,
        'lastMessageType': type.toString().split('.').last,
        'lastSharedPostId': sharedPostId,
        'lastSharedPostCaption': sharedPostCaption,
        'lastSharedPostImageUrl': sharedPostImageUrl,
        'lastMessageAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ========== COMMENTS ==========

  Future<String> createComment({
    required String postId,
    required String userId,
    required String text,
    String? parentCommentId,
    bool isAnonymous = false,
  }) async {
    try {
      final ref = _posts.doc(postId).collection('comments').doc();

      await ref.set({
        'id': ref.id,
        'postId': postId,
        'userId': userId,
        'text': text,
        'parentCommentId': parentCommentId,
        'isAnonymous': isAnonymous,
        'likedByIds': <String>[],
        'createdAt': Timestamp.now(),
      });

      await _posts.doc(postId).update({
        'commentCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      return ref.id;
    } catch (e) {
      throw Exception('Failed to create comment: $e');
    }
  }

  Future<List<CommentModel>> getCommentsForPost(String postId) async {
    try {
      final snapshot = await _posts
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CommentModel(
          id: doc.id,
          postId: data['postId'] as String,
          userId: data['userId'] as String,
          text: data['text'] as String,
          parentCommentId: data['parentCommentId'] as String?,
          isAnonymous: data['isAnonymous'] as bool? ?? false,
          likedByIds: List<String>.from(data['likedByIds'] ?? <String>[]),
          createdAt: _readDate(data, 'createdAt'),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      await _posts.doc(postId).collection('comments').doc(commentId).delete();

      final postRef = _posts.doc(postId);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(postRef);
        final current = (snap.data()?['commentCount'] as int?) ?? 0;
        txn.update(postRef, {
          'commentCount': current > 0 ? current - 1 : 0,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    try {
      await _posts.doc(postId).collection('comments').doc(commentId).update({
        'likedByIds': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to like comment: $e');
    }
  }

  Future<void> unlikeComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    try {
      await _posts.doc(postId).collection('comments').doc(commentId).update({
        'likedByIds': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to unlike comment: $e');
    }
  }

  // ========== JOURNAL ==========

  Future<void> saveJournalEntry({
    required String userId,
    required JournalEntry entry,
  }) async {
    try {
      await _journalRef(userId).doc(entry.id).set({
        'id': entry.id,
        'title': entry.title,
        'content': entry.content,
        'mood': entry.mood,
        'date': Timestamp.fromDate(entry.date),
        'createdAt': Timestamp.fromDate(entry.createdAt),
        'updatedAt': Timestamp.now(),
        'tags': entry.tags,
        'isPrivate': entry.isPrivate,
        'coverEmoji': entry.coverEmoji,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save journal entry: $e');
    }
  }

  Future<void> deleteJournalEntry({
    required String userId,
    required String entryId,
  }) async {
    try {
      await _journalRef(userId).doc(entryId).delete();
    } catch (e) {
      throw Exception('Failed to delete journal entry: $e');
    }
  }

  Future<List<JournalEntry>> getJournalEntries(
    String userId, {
    int limit = 200,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _journalRef(userId).orderBy('date', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(_journalEntryFromFirestore).toList();
    } catch (e) {
      throw Exception('Failed to fetch journal entries: $e');
    }
  }

  Stream<List<JournalEntry>> watchJournalEntries(
    String userId, {
    int limit = 400,
  }) {
    return _journalRef(userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(_journalEntryFromFirestore).toList());
  }

  // ========== MOOD ==========

  Future<void> saveMoodEntry({
    required String userId,
    required MoodEntry entry,
  }) async {
    try {
      final entryDayKey =
          '${entry.date.year.toString().padLeft(4, '0')}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
      await _moodRef(userId).doc(entryDayKey).set({
        'id': entry.id,
        'mood': entry.mood,
        'emoji': entry.emoji,
        'note': entry.note,
        'date': Timestamp.fromDate(entry.date),
        'createdAt': Timestamp.fromDate(entry.createdAt),
        'updatedAt': Timestamp.now(),
        'isPeriodDay': entry.isPeriodDay,
        'painLevel': entry.painLevel,
        'symptoms': entry.symptoms,
        'flow': entry.flow,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save mood entry: $e');
    }
  }

  Future<List<MoodEntry>> getMoodEntries(
    String userId, {
    int limit = 365,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _moodRef(userId).orderBy('date', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(_moodEntryFromFirestore).toList();
    } catch (e) {
      throw Exception('Failed to fetch mood entries: $e');
    }
  }

  Stream<List<MoodEntry>> watchMoodEntries(
    String userId, {
    int limit = 730,
  }) {
    return _moodRef(userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_moodEntryFromFirestore).toList());
  }

  Future<void> deleteMoodEntry({
    required String userId,
    required String moodEntryId,
  }) async {
    try {
      // Entries are normally keyed by yyyy-MM-dd doc id, but older entries may use custom ids.
      await _moodRef(userId).doc(moodEntryId).delete();

      final query =
          await _moodRef(userId).where('id', isEqualTo: moodEntryId).get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete mood entry: $e');
    }
  }

  // ========== HELPERS ==========

  UserModel _userFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      id: (data['id'] as String?) ?? doc.id,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      bio: data['bio'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      email: data['email'] as String? ?? '',
      createdAt: _readDate(data, 'createdAt'),
      isPublic: data['isPublic'] as bool? ?? true,
      followerIds: List<String>.from(data['followerIds'] ?? <String>[]),
      followingIds: List<String>.from(data['followingIds'] ?? <String>[]),
      pendingFollowRequests:
          List<String>.from(data['pendingFollowRequests'] ?? <String>[]),
      pronouns: data['pronouns'] as String?,
      website: data['website'] as String?,
    );
  }

  PostModel _postFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PostModel(
      id: doc.id,
      userId: data['userId'] as String,
      username: data['username'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      caption: data['caption'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      likedByIds: List<String>.from(data['likedByIds'] ?? <String>[]),
      commentCount: data['commentCount'] as int? ?? 0,
      createdAt: _readDate(data, 'createdAt'),
      tags: List<String>.from(data['tags'] ?? <String>[]),
      visibility: PostVisibility.values.firstWhere(
        (visibility) =>
            visibility.toString().split('.').last == data['visibility'],
        orElse: () => PostVisibility.public,
      ),
    );
  }

  JournalEntry _journalEntryFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return JournalEntry(
      id: (data['id'] as String?) ?? doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      mood: data['mood'] as String? ?? 'calm',
      date: _readDate(data, 'date'),
      createdAt: _readDate(data, 'createdAt', fallbackKey: 'date'),
      updatedAt: _readDate(data, 'updatedAt', fallbackKey: 'createdAt'),
      tags: List<String>.from(data['tags'] ?? <String>[]),
      isPrivate: data['isPrivate'] as bool? ?? true,
      coverEmoji: data['coverEmoji'] as String?,
    );
  }

  MoodEntry _moodEntryFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return MoodEntry(
      id: data['id'] as String? ?? doc.id,
      mood: data['mood'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '',
      note: data['note'] as String?,
      date: _readDate(data, 'date'),
      createdAt: _readDate(data, 'createdAt', fallbackKey: 'date'),
      updatedAt: _readDate(data, 'updatedAt', fallbackKey: 'createdAt'),
      isPeriodDay: data['isPeriodDay'] as bool? ?? false,
      painLevel: data['painLevel'] as int?,
      symptoms: List<String>.from(data['symptoms'] ?? <String>[]),
      flow: data['flow'] as String?,
    );
  }

  ChatModel _chatFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final lastMessageTypeValue = data['lastMessageType'] as String? ?? 'text';
    final lastMessageType = ChatMessageType.values.firstWhere(
      (candidate) => candidate.toString().split('.').last == lastMessageTypeValue,
      orElse: () => ChatMessageType.text,
    );

    return ChatModel(
      id: (data['id'] as String?) ?? doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? <String>[]),
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageType: lastMessageType,
      lastSharedPostId: data['lastSharedPostId'] as String?,
      lastSharedPostCaption: data['lastSharedPostCaption'] as String?,
      lastSharedPostImageUrl: data['lastSharedPostImageUrl'] as String?,
      lastMessageAt: _readDate(data, 'lastMessageAt', fallbackKey: 'createdAt'),
      createdAt: _readDate(data, 'createdAt', fallbackKey: 'lastMessageAt'),
    );
  }

  ChatMessageModel _chatMessageFromFirestore(
    String chatId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final typeValue = data['type'] as String? ?? 'text';
    final type = ChatMessageType.values.firstWhere(
      (candidate) => candidate.toString().split('.').last == typeValue,
      orElse: () => ChatMessageType.text,
    );

    return ChatMessageModel(
      id: (data['id'] as String?) ?? doc.id,
      chatId: data['chatId'] as String? ?? chatId,
      senderId: data['senderId'] as String? ?? '',
      type: type,
      text: data['text'] as String?,
      sharedPostId: data['sharedPostId'] as String?,
      sharedPostCaption: data['sharedPostCaption'] as String?,
      sharedPostImageUrl: data['sharedPostImageUrl'] as String?,
      sharedPostAuthorId: data['sharedPostAuthorId'] as String?,
      createdAt: _readDate(data, 'createdAt'),
    );
  }

  DateTime _readDate(
    Map<String, dynamic> data,
    String key, {
    String? fallbackKey,
  }) {
    final value = data[key] ?? (fallbackKey != null ? data[fallbackKey] : null);
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime _readDynamicDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
    return DateTime.now();
  }

  Future<String?> _maybeUploadImage({
    required String? imagePathOrUrl,
    Uint8List? imageBytes,
    String? imageFileName,
    required String folder,
    required String userId,
    required String objectId,
    required double? forcedAspectRatio,
  }) async {
    final imagePath = imagePathOrUrl;
    final sourceBytes = imageBytes;
    final hasImagePath = imagePath != null && imagePath.isNotEmpty;
    final hasImageBytes = sourceBytes != null && sourceBytes.isNotEmpty;

    if (!hasImagePath && !hasImageBytes) {
      return null;
    }

    if (hasImagePath && _isRemoteUrl(imagePath!)) {
      return imagePath;
    }

    if (!_externalImageHostService.isConfigured) {
      throw Exception(
        'Image upload is locked to external host only. Configure Cloudinary environment values before uploading images.',
      );
    }

    try {
      String? externalUrl;

      Uint8List? processedBytes;
      if (hasImageBytes) {
        processedBytes = sourceBytes;
      } else if (hasImagePath) {
        try {
          final localFile = File(imagePath!);
          if (await localFile.exists()) {
            processedBytes = await localFile.readAsBytes();
          }
        } catch (_) {
          processedBytes = null;
        }
      }

      if (processedBytes != null && forcedAspectRatio != null) {
        processedBytes = _normalizeImageToAspectRatio(
          processedBytes,
          aspectRatio: forcedAspectRatio,
        );
      }

      if (processedBytes != null) {
        externalUrl = await _externalImageHostService.uploadImageFromBytes(
          bytes: processedBytes,
          fileName: (imageFileName != null && imageFileName.isNotEmpty)
              ? imageFileName
              : '$objectId.jpg',
          folder: folder,
          userId: userId,
          objectId: objectId,
        );
      } else if (hasImagePath) {
        externalUrl = await _externalImageHostService.uploadImageFromFilePath(
          filePath: imagePath!,
          folder: folder,
          userId: userId,
          objectId: objectId,
        );
      }

      if (externalUrl == null || externalUrl.isEmpty) {
        throw Exception('External image host returned an empty upload URL.');
      }

      return externalUrl;
    } catch (externalError) {
      throw Exception('External image upload failed: $externalError');
    }
  }

  Uint8List _normalizeImageToAspectRatio(
    Uint8List sourceBytes, {
    required double aspectRatio,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return sourceBytes;
    }

    final srcWidth = decoded.width;
    final srcHeight = decoded.height;
    if (srcWidth <= 0 || srcHeight <= 0) {
      return sourceBytes;
    }

    final srcRatio = srcWidth / srcHeight;
    if ((srcRatio - aspectRatio).abs() < 0.01) {
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    }

    var cropWidth = srcWidth;
    var cropHeight = srcHeight;
    var offsetX = 0;
    var offsetY = 0;

    if (srcRatio > aspectRatio) {
      cropWidth = (srcHeight * aspectRatio).round();
      offsetX = ((srcWidth - cropWidth) / 2).round();
    } else {
      cropHeight = (srcWidth / aspectRatio).round();
      offsetY = ((srcHeight - cropHeight) / 2).round();
    }

    final cropped = img.copyCrop(
      decoded,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('gs://');
  }

  List<List<String>> _chunkIds(List<String> ids, int chunkSize) {
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      chunks.add(ids.sublist(i, end));
    }
    return chunks;
  }
}
