import 'package:flutter_test/flutter_test.dart';
import 'package:bloomy/models/models.dart';

void main() {
  group('UserModel', () {
    test('fromMap parses relationship fields', () {
      final now = DateTime.now();
      final map = {
        'id': 'u1',
        'username': 'alice',
        'displayName': 'Alice',
        'bio': 'Hello',
        'avatarUrl': 'https://example.com/a.png',
        'email': 'alice@example.com',
        'createdAt': now.toIso8601String(),
        'isPublic': false,
        'followerIds': ['u2', 'u3'],
        'followingIds': ['u4'],
        'pendingFollowRequests': ['u5'],
        'pronouns': 'she/her',
        'website': 'https://example.com',
      };

      final user = UserModel.fromMap(map);

      expect(user.id, 'u1');
      expect(user.isPublic, isFalse);
      expect(user.followerIds.length, 2);
      expect(user.followingIds, ['u4']);
      expect(user.pendingFollowRequests, ['u5']);
      expect(user.pronouns, 'she/her');
    });
  });

  group('PostModel', () {
    test('fromMap parses visibility and likes fallback', () {
      final now = DateTime.now();
      final map = {
        'id': 'p1',
        'userId': 'u1',
        'caption': 'test',
        'isAnonymous': false,
        'likes': ['u2'],
        'commentCount': 1,
        'createdAt': now.toIso8601String(),
        'tags': ['one'],
        'visibility': 'followersOnly',
      };

      final post = PostModel.fromMap(map);

      expect(post.id, 'p1');
      expect(post.visibility, PostVisibility.followersOnly);
      expect(post.likedByIds, ['u2']);
      expect(post.commentCount, 1);
    });
  });

  group('NotificationModel', () {
    test('fromMap parses notification type and timestamps', () {
      final now = DateTime.now();
      final map = {
        'id': 'n1',
        'toUserId': 'u1',
        'fromUserId': 'u2',
        'type': 'followRequest',
        'isRead': false,
        'createdAt': now.toIso8601String(),
      };

      final notif = NotificationModel.fromMap(map);

      expect(notif.id, 'n1');
      expect(notif.type, NotificationType.followRequest);
      expect(notif.isRead, isFalse);
    });
  });
}
