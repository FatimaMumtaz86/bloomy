DateTime _parseDate(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) {
    return value;
  }

  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value != null) {
    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {}
  }

  return fallback ?? DateTime.now();
}

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String email;
  final DateTime createdAt;
  final bool isPublic;
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> pendingFollowRequests;
  final String? pronouns;
  final String? website;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    required this.email,
    required this.createdAt,
    this.isPublic = true,
    this.followerIds = const [],
    this.followingIds = const [],
    this.pendingFollowRequests = const [],
    this.pronouns,
    this.website,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'isPublic': isPublic,
    'followerIds': followerIds,
    'followingIds': followingIds,
    'pendingFollowRequests': pendingFollowRequests,
    'pronouns': pronouns,
    'website': website,
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    id: m['id'],
    username: m['username'],
    displayName: m['displayName'],
    bio: m['bio'],
    avatarUrl: m['avatarUrl'],
    email: m['email'],
    createdAt: _parseDate(m['createdAt']),
    isPublic: m['isPublic'] ?? true,
    followerIds: List<String>.from(m['followerIds'] ?? []),
    followingIds: List<String>.from(m['followingIds'] ?? []),
    pendingFollowRequests: List<String>.from(m['pendingFollowRequests'] ?? []),
    pronouns: m['pronouns'],
    website: m['website'],
  );
}

enum PostVisibility { public, followersOnly, private }

class PostModel {
  final String id;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String? imageUrl;
  final String caption;
  final bool isAnonymous;
  final List<String> likedByIds;
  final int commentCount;
  final DateTime createdAt;
  final List<String> tags;
  final PostVisibility visibility;

  PostModel({
    required this.id,
    required this.userId,
    this.username,
    this.avatarUrl,
    this.imageUrl,
    required this.caption,
    this.isAnonymous = false,
    this.likedByIds = const [],
    this.commentCount = 0,
    required this.createdAt,
    this.tags = const [],
    this.visibility = PostVisibility.public,
  });

  // For backward compatibility with existing code that uses 'likes'
  List<String> get likes => likedByIds;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'username': username,
    'avatarUrl': avatarUrl,
    'imageUrl': imageUrl,
    'caption': caption,
    'isAnonymous': isAnonymous,
    'likedByIds': likedByIds,
    'commentCount': commentCount,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
    'visibility': visibility.toString().split('.').last,
  };

  factory PostModel.fromMap(Map<String, dynamic> m) {
    PostVisibility visibility = PostVisibility.public;
    if (m['visibility'] != null) {
      final visStr = m['visibility'].toString();
      visibility = PostVisibility.values.firstWhere(
        (v) => v.toString().split('.').last == visStr,
        orElse: () => PostVisibility.public,
      );
    }
    return PostModel(
      id: m['id'],
      userId: m['userId'],
      username: m['username'],
      avatarUrl: m['avatarUrl'],
      imageUrl: m['imageUrl'],
      caption: m['caption'],
      isAnonymous: m['isAnonymous'] ?? false,
      likedByIds: List<String>.from(m['likedByIds'] ?? m['likes'] ?? []),
      commentCount: m['commentCount'] ?? 0,
      createdAt: _parseDate(m['createdAt']),
      tags: List<String>.from(m['tags'] ?? []),
      visibility: visibility,
    );
  }
}

class JournalEntry {
  final String id;
  final String title;
  final String content;
  final String mood;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isPrivate;
  final String? coverEmoji;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.date,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tags = const [],
    this.isPrivate = true,
    this.coverEmoji,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'mood': mood,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
    'isPrivate': isPrivate,
    'coverEmoji': coverEmoji,
  };

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
    id: m['id'],
    title: m['title'],
    content: m['content'],
    mood: m['mood'],
    date: _parseDate(m['date']),
    createdAt: _parseDate(m['createdAt'], fallback: _parseDate(m['date'])),
    updatedAt: _parseDate(
      m['updatedAt'],
      fallback: _parseDate(m['createdAt'], fallback: _parseDate(m['date'])),
    ),
    tags: List<String>.from(m['tags'] ?? []),
    isPrivate: m['isPrivate'] ?? true,
    coverEmoji: m['coverEmoji'],
  );
}

class MoodEntry {
  final String id;
  final String mood;
  final String emoji;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPeriodDay;
  final int? painLevel;
  final List<String> symptoms;
  final String? flow;

  MoodEntry({
    required this.id,
    required this.mood,
    required this.emoji,
    this.note,
    required this.date,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPeriodDay = false,
    this.painLevel,
    this.symptoms = const [],
    this.flow,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'mood': mood,
    'emoji': emoji,
    'note': note,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPeriodDay': isPeriodDay,
    'painLevel': painLevel,
    'symptoms': symptoms,
    'flow': flow,
  };

  factory MoodEntry.fromMap(Map<String, dynamic> m) => MoodEntry(
    id: m['id'],
    mood: m['mood'],
    emoji: m['emoji'],
    note: m['note'],
    date: _parseDate(m['date']),
    createdAt: _parseDate(m['createdAt'], fallback: _parseDate(m['date'])),
    updatedAt: _parseDate(
      m['updatedAt'],
      fallback: _parseDate(m['createdAt'], fallback: _parseDate(m['date'])),
    ),
    isPeriodDay: m['isPeriodDay'] ?? false,
    painLevel: m['painLevel'],
    symptoms: List<String>.from(m['symptoms'] ?? []),
    flow: m['flow'],
  );
}

class CyclePrediction {
  final DateTime predictedNextPeriodStart;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final int averageCycleLengthDays;
  final double confidence;

  CyclePrediction({
    required this.predictedNextPeriodStart,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.averageCycleLengthDays,
    required this.confidence,
  });
}

class PinItem {
  final String id;
  final String? imageUrl;
  final String? title;
  final String? boardId;
  final DateTime createdAt;

  PinItem({
    required this.id,
    this.imageUrl,
    this.title,
    this.boardId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'imageUrl': imageUrl, 'title': title,
    'boardId': boardId, 'createdAt': createdAt.toIso8601String(),
  };

  factory PinItem.fromMap(Map<String, dynamic> m) => PinItem(
    id: m['id'], imageUrl: m['imageUrl'], title: m['title'],
    boardId: m['boardId'], createdAt: _parseDate(m['createdAt']),
  );
}

class Board {
  final String id;
  final String name;
  final String? coverUrl;
  final List<PinItem> pins;
  final DateTime createdAt;

  Board({
    required this.id,
    required this.name,
    this.coverUrl,
    this.pins = const [],
    required this.createdAt,
  });
}

class PinModel {
  final String id;
  final String userId;
  final String? username;
  final String? imageUrl;
  final String title;
  final String? description;
  final String boardId;
  final bool isPublic;
  final List<String> likedByIds;
  final List<String> savedByIds;
  final DateTime createdAt;
  final List<String> tags;

  PinModel({
    required this.id,
    required this.userId,
    this.username,
    this.imageUrl,
    required this.title,
    this.description,
    required this.boardId,
    this.isPublic = true,
    this.likedByIds = const [],
    this.savedByIds = const [],
    required this.createdAt,
    this.tags = const [],
  });

  // For backward compatibility
  get boardName => boardId;
  List<String> get likes => likedByIds;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'username': username,
    'imageUrl': imageUrl,
    'title': title,
    'description': description,
    'boardId': boardId,
    'isPublic': isPublic,
    'likedByIds': likedByIds,
    'savedByIds': savedByIds,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
  };

  factory PinModel.fromMap(Map<String, dynamic> m) => PinModel(
    id: m['id'],
    userId: m['userId'],
    username: m['username'],
    imageUrl: m['imageUrl'],
    title: m['title'],
    description: m['description'],
    boardId: m['boardId'] ?? m['boardName'] ?? '',
    isPublic: m['isPublic'] ?? true,
    likedByIds: List<String>.from(m['likedByIds'] ?? m['likes'] ?? []),
    savedByIds: List<String>.from(m['savedByIds'] ?? []),
    createdAt: _parseDate(m['createdAt']),
    tags: List<String>.from(m['tags'] ?? []),
  );
}

class BoardModel {
  final String id;
  final String userId;
  final String name;
  final String? coverImageUrl;
  final String? description;
  final bool isPublic;
  final List<String> pinIds;
  final DateTime createdAt;

  BoardModel({
    required this.id,
    required this.userId,
    required this.name,
    this.coverImageUrl,
    this.description,
    this.isPublic = false,
    this.pinIds = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'coverImageUrl': coverImageUrl,
    'description': description,
    'isPublic': isPublic,
    'pinIds': pinIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BoardModel.fromMap(Map<String, dynamic> m) => BoardModel(
    id: m['id'],
    userId: m['userId'],
    name: m['name'],
    coverImageUrl: m['coverImageUrl'],
    description: m['description'],
    isPublic: m['isPublic'] ?? false,
    pinIds: List<String>.from(m['pinIds'] ?? []),
    createdAt: _parseDate(m['createdAt']),
  );
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final String? parentCommentId;
  final DateTime createdAt;
  final bool isAnonymous;
  final List<String> likedByIds;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    this.parentCommentId,
    required this.createdAt,
    this.isAnonymous = false,
    this.likedByIds = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'postId': postId,
    'userId': userId,
    'text': text,
    'parentCommentId': parentCommentId,
    'createdAt': createdAt.toIso8601String(),
    'isAnonymous': isAnonymous,
    'likedByIds': likedByIds,
  };

  factory CommentModel.fromMap(Map<String, dynamic> m) => CommentModel(
    id: m['id'],
    postId: m['postId'],
    userId: m['userId'],
    text: m['text'],
    parentCommentId: m['parentCommentId'],
    createdAt: _parseDate(m['createdAt']),
    isAnonymous: m['isAnonymous'] ?? false,
    likedByIds: List<String>.from(m['likedByIds'] ?? []),
  );
}

enum NotificationType { like, comment, follow, followRequest, followAccepted }

class NotificationModel {
  final String id;
  final String toUserId;
  final String fromUserId;
  final NotificationType type;
  final String? postId;
  final String? pinId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.toUserId,
    required this.fromUserId,
    required this.type,
    this.postId,
    this.pinId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'toUserId': toUserId,
    'fromUserId': fromUserId,
    'type': type.toString().split('.').last,
    'postId': postId,
    'pinId': pinId,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NotificationModel.fromMap(Map<String, dynamic> m) {
    NotificationType type = NotificationType.like;
    if (m['type'] != null) {
      final typeStr = m['type'].toString();
      type = NotificationType.values.firstWhere(
        (t) => t.toString().split('.').last == typeStr,
        orElse: () => NotificationType.like,
      );
    }
    return NotificationModel(
      id: m['id'],
      toUserId: m['toUserId'],
      fromUserId: m['fromUserId'],
      type: type,
      postId: m['postId'],
      pinId: m['pinId'],
      isRead: m['isRead'] ?? false,
      createdAt: _parseDate(m['createdAt']),
    );
  }
}

enum ChatMessageType { text, sharedPost }

class ChatModel {
  final String id;
  final List<String> participantIds;
  final String? groupName;
  final String lastMessageText;
  final String? lastMessageSenderId;
  final ChatMessageType lastMessageType;
  final String? lastSharedPostId;
  final String? lastSharedPostCaption;
  final String? lastSharedPostImageUrl;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.participantIds,
    this.groupName,
    required this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageType = ChatMessageType.text,
    this.lastSharedPostId,
    this.lastSharedPostCaption,
    this.lastSharedPostImageUrl,
    required this.lastMessageAt,
    required this.createdAt,
  });

  bool get isGroup =>
      participantIds.length > 2 ||
      (groupName != null && groupName!.trim().isNotEmpty);

  Map<String, dynamic> toMap() => {
    'id': id,
    'participantIds': participantIds,
    'groupName': groupName,
    'lastMessageText': lastMessageText,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageType': lastMessageType.toString().split('.').last,
    'lastSharedPostId': lastSharedPostId,
    'lastSharedPostCaption': lastSharedPostCaption,
    'lastSharedPostImageUrl': lastSharedPostImageUrl,
    'lastMessageAt': lastMessageAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatModel.fromMap(Map<String, dynamic> m) {
    ChatMessageType lastMessageType = ChatMessageType.text;
    if (m['lastMessageType'] != null) {
      final typeValue = m['lastMessageType'].toString();
      lastMessageType = ChatMessageType.values.firstWhere(
        (candidate) => candidate.toString().split('.').last == typeValue,
        orElse: () => ChatMessageType.text,
      );
    }

    return ChatModel(
      id: m['id'],
      participantIds: List<String>.from(m['participantIds'] ?? []),
      groupName: m['groupName'],
      lastMessageText: m['lastMessageText'] ?? '',
      lastMessageSenderId: m['lastMessageSenderId'],
      lastMessageType: lastMessageType,
      lastSharedPostId: m['lastSharedPostId'],
      lastSharedPostCaption: m['lastSharedPostCaption'],
      lastSharedPostImageUrl: m['lastSharedPostImageUrl'],
      lastMessageAt: _parseDate(
        m['lastMessageAt'],
        fallback: _parseDate(m['createdAt']),
      ),
      createdAt: _parseDate(m['createdAt']),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final ChatMessageType type;
  final String? text;
  final String? sharedPostId;
  final String? sharedPostCaption;
  final String? sharedPostImageUrl;
  final String? sharedPostAuthorId;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text,
    this.sharedPostId,
    this.sharedPostCaption,
    this.sharedPostImageUrl,
    this.sharedPostAuthorId,
    required this.createdAt,
  });

  bool get isText => type == ChatMessageType.text;
  bool get isSharedPost => type == ChatMessageType.sharedPost;

  Map<String, dynamic> toMap() => {
    'id': id,
    'chatId': chatId,
    'senderId': senderId,
    'type': type.toString().split('.').last,
    'text': text,
    'sharedPostId': sharedPostId,
    'sharedPostCaption': sharedPostCaption,
    'sharedPostImageUrl': sharedPostImageUrl,
    'sharedPostAuthorId': sharedPostAuthorId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessageModel.fromMap(Map<String, dynamic> m) {
    ChatMessageType resolvedType = ChatMessageType.text;
    if (m['type'] != null) {
      final typeValue = m['type'].toString();
      resolvedType = ChatMessageType.values.firstWhere(
        (candidate) => candidate.toString().split('.').last == typeValue,
        orElse: () => ChatMessageType.text,
      );
    }

    return ChatMessageModel(
      id: m['id'],
      chatId: m['chatId'],
      senderId: m['senderId'],
      type: resolvedType,
      text: m['text'],
      sharedPostId: m['sharedPostId'],
      sharedPostCaption: m['sharedPostCaption'],
      sharedPostImageUrl: m['sharedPostImageUrl'],
      sharedPostAuthorId: m['sharedPostAuthorId'],
      createdAt: _parseDate(m['createdAt']),
    );
  }
}
