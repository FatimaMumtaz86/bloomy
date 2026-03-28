# 🌸 Bloomy — MVP Production Architecture & Implementation Plan
> "A safe space to be you" — Full plan for Copilot to implement immediately

---

## 1. CURRENT STATE AUDIT

### What Exists (Working)
- Flutter app with Provider state management
- Splash → Onboarding → Auth → Home navigation flow
- `AuthProvider`, `PostProvider`, `JournalProvider`, `MoodProvider`, `PinProvider`, `FollowProvider`, `SavedPostProvider`, `UserProvider`
- 6 screens: Feed (ForYou + Anonymous tabs), Pins (Pins + Boards tabs), Search/Discover, Mood tracker, Journal/Diary, Profile
- SharedPreferences local storage (all data is local — no backend)
- Staggered grid for pins, TableCalendar for mood
- Post creation sheet with image picker + anonymous toggle
- Basic follow/unfollow logic (local only)

### Critical Issues to Fix
1. **No backend** — all data lives in SharedPreferences. Multi-user social features don't work.
2. **Post creation** has no destination picker — user can't choose: FYP post / Pin / Anonymous
3. **For You feed** shows ALL public posts, not follow-based logic
4. **Private account posts** are not gated to followers-only
5. **Pins tab** shows only current user's pins — no community pins discovery
6. **Profile → My Space** section is missing (saved posts, liked posts)
7. **Single account per device** — no real multi-user
8. **No comments** on posts
9. **No story/short-lived content** (listed in MVP goals)
10. **Period tracker** exists but is basic — no cycle prediction
11. **Vision board** in profile is not a real board builder
12. **No notifications** (follow requests, likes, comments)
13. **Post type is conflated** — `PostModel` tries to be both a FYP post and a Pin

---

## 2. ARCHITECTURE DECISION

### Backend: Firebase (Recommended for MVP Speed)
Use **Firebase** — it integrates natively with Flutter, handles auth, real-time DB, file storage, and notifications out of the box.

```
firebase_auth         → Login / Signup / Session
cloud_firestore       → All data (posts, pins, journals, moods, follows)
firebase_storage      → Image uploads (posts, pins, avatar, boards)
firebase_messaging    → Push notifications
```

### State Management: Keep Provider, extend cleanly
The existing Provider setup is good. Extend it to be Firebase-backed instead of SharedPreferences-backed.

---

## 3. DATA MODELS (Revised & Extended)

### 3.1 UserModel (extend existing)
```dart
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String email;
  final DateTime createdAt;
  final bool isPublic;           // public = anyone sees posts; private = followers only
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> pendingFollowRequests; // for private accounts
  final String? pronouns;        // NEW — girls app, this matters
  final String? website;         // NEW
}
```

### 3.2 PostModel (revised — FYP posts only, not pins)
```dart
class PostModel {
  final String id;
  final String userId;
  final String? imageUrl;
  final String caption;
  final bool isAnonymous;        // if true, userId is hidden in UI
  final List<String> likedByIds;
  final int commentCount;
  final DateTime createdAt;
  final List<String> tags;
  final PostVisibility visibility; // public | followersOnly | private
}

enum PostVisibility { public, followersOnly, private }
```

### 3.3 PinModel (revised — community-visible)
```dart
class PinModel {
  final String id;
  final String userId;           // owner
  final String? imageUrl;
  final String title;
  final String? description;
  final String boardId;          // links to a Board
  final bool isPublic;           // show in community pins tab
  final List<String> likedByIds;
  final List<String> savedByIds; // who saved this pin
  final DateTime createdAt;
  final List<String> tags;
}
```

### 3.4 BoardModel (NEW — proper boards)
```dart
class BoardModel {
  final String id;
  final String userId;
  final String name;
  final String? coverImageUrl;
  final String? description;
  final bool isPublic;
  final List<String> pinIds;
  final DateTime createdAt;
}
```

### 3.5 Comment (NEW)
```dart
class Comment {
  final String id;
  final String postId;           // or pinId
  final String userId;
  final String text;
  final DateTime createdAt;
  final bool isAnonymous;
}
```

### 3.6 JournalEntry (keep existing, add encryption flag)
```dart
class JournalEntry {
  // ... existing fields ...
  final bool isPrivate;   // always private but flag for future encrypted export
  final String? coverEmoji;
}
```

### 3.7 MoodEntry (extend existing)
```dart
class MoodEntry {
  // ... existing fields ...
  final List<String> symptoms;      // ['cramps', 'headache', 'bloating']
  final String? flow;               // 'light' | 'medium' | 'heavy'
  final bool isPeriodDay;
}
```

### 3.8 Notification (NEW)
```dart
class NotificationModel {
  final String id;
  final String toUserId;
  final String fromUserId;
  final NotificationType type;      // like, comment, follow, followRequest, followAccepted
  final String? postId;
  final bool isRead;
  final DateTime createdAt;
}
```

---

## 4. FEATURE SPEC (What to Build)

### 4.1 POST CREATION — Unified Sheet with Destination Picker

**This is the most important UX change.** When user taps `+` from ANY tab, show a bottom sheet with:

```
┌─────────────────────────────┐
│  Create Something 🌸        │
│                             │
│  📸  [image picker area]    │
│                             │
│  [caption text field]       │
│                             │
│  Post to:                   │
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │ FYP  │ │ Pins │ │Anon  ││
│  │ Post │ │Board │ │Post  ││
│  └──────┘ └──────┘ └────── ││
│                             │
│  (if Pin selected)          │
│  Board: [dropdown]          │
│                             │
│  Tags: [chip input]         │
│                             │
│  [Post] button              │
└─────────────────────────────┘
```

Each tab's own `+` FAB also opens this sheet but pre-selects the relevant destination.

---

### 4.2 FOR YOU FEED (FYP)

**Feed algorithm logic:**

```
ForYou tab shows:
  - Posts from accounts you follow
  - Posts from public accounts (discovery, ranked by recency)
  - EXCLUDE: posts from private accounts you don't follow
  
Following tab (add this new tab):
  - Only posts from people you follow
  - Includes private account posts if you're an accepted follower

Anonymous tab:
  - All anonymous posts (no account gating)
  - No author info shown ever
  
Tab structure:  ✨ For You  |  👥 Following  |  🤍 Anonymous
```

**Private account gating:**
- If `user.isPublic == false`, their posts only appear in the Following tab for accepted followers
- Their profile is visible but posts/pins are blurred/hidden for non-followers
- Follow button shows "Request" instead of "Follow"

---

### 4.3 PINS SECTION

**Tab structure:**
```
📌 Discover  |  🗂 My Boards
```

**Discover tab:**
- Staggered grid (keep existing flutter_staggered_grid_view)
- Shows ALL public pins from all users
- Filter chips at top: All | Dream Life | Aesthetic | Goals | Fashion | Self Care | Food | Travel
- Tap pin → full view with save button, like, comment

**My Boards tab:**
- Shows current user's boards
- Tap board → full board view with all pins in it
- Create new board button
- Board cover auto-sets from first pin image

---

### 4.4 PROFILE SCREEN

**Structure:**
```
[Header: avatar, name, @username, bio, follow/edit button]
[Stats: Posts | Pins | Followers | Following]
[Tab Bar:]
  Posts | Pins & Boards | My Space
```

**My Space tab (NEW):**
```
  Sub-tabs:
    Saved Posts | Liked Posts | Saved Pins | Journal Highlights
```

**Other user's profile:**
- If private + not following: blur posts, show "Follow to see posts"
- If private + pending: show "Requested"
- If private + following: show all posts
- Public: show all posts always

---

### 4.5 FOLLOW SYSTEM

```
Public account:
  - Tap Follow → instantly followed
  - Their posts appear in your Following tab

Private account:
  - Tap Follow → sends Follow Request
  - Owner gets notification
  - Owner can Accept / Decline in Notifications screen
  - After accept → appear in Following tab
  - Follower count only updates after accept
```

---

### 4.6 JOURNAL / DIARY

- Rich text editor (bold, italic, emoji)
- Mood tag on each entry
- Lock with device biometrics (local_auth package)
- Calendar view to browse by date
- Streak counter ("You've journaled 7 days in a row 🌸")
- Export to PDF (optional MVP stretch)

---

### 4.7 MOOD & PERIOD TRACKER

**Two sub-views:**
1. **Daily Mood Log** — tap emoji, add note, add symptoms
2. **Cycle Calendar** — mark period days, see predicted next cycle

**Period prediction (simple):**
- Track start dates
- Average last 3 cycles for prediction
- Show "Period expected in X days" on home / mood screen

**Symptoms chips:** cramps, headache, bloating, fatigue, mood swings, spotting, cravings

---

### 4.8 NOTIFICATIONS SCREEN (NEW)

- Bell icon in app bar (home/feed)
- Badge count on icon
- List: likes, comments, new followers, follow requests
- "Accept / Decline" buttons inline for follow requests

---

### 4.9 COMMENTS (NEW)

- Tap comment icon on post → slide-up comment sheet
- Anonymous posts: commenters can also comment anonymously
- Normal posts: comments show username
- Like individual comments

---

## 5. NAVIGATION STRUCTURE

```
HomeScreen (bottom nav):
  0 → FeedScreen        (icon: home)
  1 → PinsScreen        (icon: push_pin)
  2 → SearchScreen      (icon: search / discover)
  3 → MoodScreen        (icon: favorite / heart)
  4 → JournalScreen     (icon: book)
  5 → ProfileScreen     (icon: person)

AppBar icons (Feed):
  🔔 NotificationsScreen  (new)
  
FAB (+):
  CreatePostSheet (universal, destination picker)

Additional routes:
  /user/:id             → OtherUserProfileScreen
  /post/:id             → PostDetailScreen (with comments)
  /pin/:id              → PinDetailScreen
  /board/:id            → BoardDetailScreen
  /notifications        → NotificationsScreen
  /settings             → SettingsScreen
```

---

## 6. NEW PACKAGES TO ADD (pubspec.yaml)

```yaml
dependencies:
  # existing: flutter, provider, shared_preferences, image_picker, 
  #           intl, table_calendar, flutter_staggered_grid_view, 
  #           uuid, flutter_animate, shimmer, google_fonts

  # ADD THESE:
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.8
  cloud_firestore: ^4.15.8
  firebase_storage: ^11.6.9
  firebase_messaging: ^14.7.19
  cached_network_image: ^3.3.1    # replace CrossPlatformImage widget
  local_auth: ^2.1.8              # journal biometric lock
  flutter_secure_storage: ^9.0.0  # secure token storage
  badges: ^3.1.2                  # notification badge
  photo_view: ^0.14.0             # full screen pin/post image viewer
  lottie: ^3.1.0                  # animations (loading, empty states)
  pull_to_refresh: ^2.0.0         # pull to refresh feed
  infinite_scroll_pagination: ^4.0.0  # paginated feed
```

---

## 7. FILE STRUCTURE (New Files to Create)

```
lib/
  main.dart                          (update: add Firebase init)
  firebase_options.dart              (generated by flutterfire configure)
  
  models/
    models.dart                      (update: extend all models)
    notification_model.dart          (new)
    comment_model.dart               (new)
    board_model.dart                 (new)
  
  providers/
    app_provider.dart                (update: all providers → Firebase-backed)
    notification_provider.dart       (new)
    comment_provider.dart            (new)
  
  services/
    auth_service.dart                (new: Firebase Auth wrapper)
    firestore_service.dart           (new: all Firestore CRUD)
    storage_service.dart             (new: Firebase Storage uploads)
    notification_service.dart        (new: FCM + local notifications)
  
  screens/
    feed_screen.dart                 (update: 3 tabs + follow logic)
    pins_screen.dart                 (update: Discover tab shows all public)
    profile_screen.dart              (update: My Space tab + other user view)
    other_user_profile_screen.dart   (new)
    post_detail_screen.dart          (new: post + comments)
    pin_detail_screen.dart           (new: pin full view + save)
    board_detail_screen.dart         (new: board pins grid)
    notifications_screen.dart        (new)
    settings_screen.dart             (new: account settings)
    journal_screen.dart              (update: biometric lock, streaks)
    mood_screen.dart                 (update: symptoms, cycle prediction)
    home_screen.dart                 (update: notification badge on bell)
    auth_screens.dart                (update: Firebase auth)
    search_screen.dart               (update: search users + pins + posts)
  
  widgets/
    bloomy_logo.dart                 (keep)
    post_card.dart                   (new: extract from feed_screen)
    pin_card.dart                    (new: extract from pins_screen)
    create_post_sheet.dart           (new: unified creation with destination picker)
    comment_sheet.dart               (new)
    user_avatar.dart                 (new: cached network image wrapper)
    mood_chip.dart                   (new: reusable mood selector)
    board_card.dart                  (new)
    follow_button.dart               (new: handles public/private logic)
    notification_badge.dart          (new)
    empty_state.dart                 (new: Lottie animated empty states)
  
  theme/
    app_theme.dart                   (keep, minor updates)
```

---

## 8. IMPLEMENTATION ORDER (Priority Sequence for Copilot)

### Phase 1 — Backend Setup (Do First)
1. Add Firebase dependencies to pubspec.yaml
2. Run `flutterfire configure` to generate firebase_options.dart
3. Create `AuthService` wrapping Firebase Auth (email/password)
4. Create `FirestoreService` with base CRUD methods
5. Create `StorageService` for image uploads
6. Update `AuthProvider` to use Firebase Auth
7. Update `main.dart` to initialize Firebase before runApp

### Phase 2 — Core Models & Providers
8. Update all models with new fields
9. Update `PostProvider` → Firestore-backed with pagination
10. Update `PinProvider` → Firestore-backed
11. Update `FollowProvider` → Firestore with follow request support
12. Create `NotificationProvider` → Firestore
13. Create `CommentProvider` → Firestore

### Phase 3 — Create Post Flow (Most Important UX)
14. Build unified `CreatePostSheet` widget with destination picker
15. Wire FYP post creation → `posts` Firestore collection
16. Wire Pin creation → `pins` collection + board selection
17. Wire Anonymous post → `posts` collection with `isAnonymous: true`
18. Replace all 3 existing FABs with this unified sheet

### Phase 4 — Feed Screen
19. Update FeedScreen to 3 tabs: For You | Following | Anonymous
20. For You: public posts ordered by recency, paginated
21. Following: posts from followed users (query by userId in followingIds)
22. Anonymous: anonymous posts only
23. Private account post gating

### Phase 5 — Pins & Boards
24. Update PinsScreen: Discover tab = all public pins
25. Build BoardDetailScreen
26. Build PinDetailScreen with save/like/comment
27. Boards in profile show user's own boards
28. Update My Boards tab in PinsScreen → only current user's boards

### Phase 6 — Profile & My Space
29. Update ProfileScreen: Posts | Pins & Boards | My Space tabs
30. My Space sub-tabs: Saved Posts | Liked Posts | Saved Pins
31. Build OtherUserProfileScreen with follow button
32. Private account blur logic

### Phase 7 — Comments & Notifications
33. Build CommentSheet widget
34. Wire comment count updates
35. Build NotificationsScreen
36. Notification badge on bell icon in AppBar
37. In-app notification creation on like/follow/comment

### Phase 8 — Polish & Production
38. Replace CrossPlatformImage with CachedNetworkImage everywhere
39. Add pull-to-refresh on Feed and Pins
40. Add infinite scroll pagination (infinite_scroll_pagination)
41. Add shimmer loading states everywhere
42. Add Lottie empty states
43. Biometric lock on Journal
44. Period cycle prediction logic in MoodProvider
45. Fix all hardcoded demo data — remove seeded mock posts

---

## 9. FIRESTORE COLLECTIONS SCHEMA

```
users/{userId}
  → UserModel fields + followerIds[], followingIds[], pendingRequests[]

posts/{postId}
  → PostModel fields
  → subcollection: comments/{commentId}

pins/{pinId}
  → PinModel fields

boards/{boardId}
  → BoardModel fields
  → userId field for querying user's boards

moods/{userId}/entries/{entryId}
  → MoodEntry fields (private to user)

journals/{userId}/entries/{entryId}
  → JournalEntry fields (private to user, never shown publicly)

notifications/{notificationId}
  → NotificationModel fields, toUserId for querying

follows/{followId}  (format: followerId_targetId)
  → { followerId, targetId, status: 'accepted'|'pending', createdAt }
```

**Firestore Indexes needed:**
- `posts`: `(isAnonymous ASC, createdAt DESC)`
- `posts`: `(userId ASC, isAnonymous ASC, createdAt DESC)`
- `pins`: `(isPublic ASC, createdAt DESC)`
- `pins`: `(userId ASC, createdAt DESC)`
- `notifications`: `(toUserId ASC, isRead ASC, createdAt DESC)`

---

## 10. FIREBASE SECURITY RULES (Important for Production)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users: anyone can read public profiles, only owner can write
    match /users/{userId} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
    
    // Posts: public posts readable by all, private gated
    match /posts/{postId} {
      allow read: if resource.data.visibility == 'public'
                  || resource.data.isAnonymous == true
                  || request.auth.uid == resource.data.userId
                  || isFollowing(request.auth.uid, resource.data.userId);
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.userId
                    || onlyUpdatingLikes();
      allow delete: if request.auth.uid == resource.data.userId;
    }
    
    // Journals: strictly private
    match /journals/{userId}/entries/{entryId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Moods: strictly private
    match /moods/{userId}/entries/{entryId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Pins: public pins readable by all
    match /pins/{pinId} {
      allow read: if resource.data.isPublic == true
                  || request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    
    // Notifications: owner only
    match /notifications/{notifId} {
      allow read, write: if request.auth.uid == resource.data.toUserId;
      allow create: if request.auth != null;
    }
  }
}
```

---

## 11. KEY UI PATTERNS TO MAINTAIN

- **Colors**: `AppColors.deepPink`, `AppColors.cream`, `AppColors.lavender`, `AppColors.softPink` — keep the existing AppTheme
- **Typography**: Google Fonts (keep existing — likely Nunito or similar soft rounded font)
- **Rounded corners**: use `BorderRadius.circular(24)` for cards, `BorderRadius.circular(16)` for chips
- **Bottom sheets**: `isScrollControlled: true`, transparent background with rounded top corners
- **Post card**: image (optional) + caption + avatar + username + like/comment/save icons
- **Pin card**: image-heavy, masonry grid, minimal text overlay
- **Anonymous post**: no avatar, shows "💜 Anonymous" instead of username, softer styling

---

## 12. WHAT NOT TO OVER-ENGINEER FOR MVP

- No in-app video (image only for now)
- No DMs / messaging
- No Stories (ephemeral content) — listed in goals but skip for MVP launch
- No AI features
- No hashtag pages
- No report/block (add basic block in Phase 2 post-launch)
- No paid tiers

---

## SUMMARY CHECKLIST FOR COPILOT

```
[ ] 1. Firebase setup (auth, firestore, storage, messaging)
[ ] 2. Update models (UserModel, PostModel, PinModel, BoardModel + new Comment, Notification)
[ ] 3. Update all Providers to be Firestore-backed
[ ] 4. Build unified CreatePostSheet with destination picker (FYP / Pin / Anonymous)
[ ] 5. Feed: 3 tabs (ForYou | Following | Anonymous) + private account gating
[ ] 6. Pins: Discover tab = community pins, My Boards = own boards
[ ] 7. Profile: 3 tabs (Posts | Pins & Boards | My Space) + OtherUserProfile
[ ] 8. Follow system with request flow for private accounts
[ ] 9. Comments on posts and pins
[ ] 10. Notifications screen + badge
[ ] 11. Journal biometric lock + streaks
[ ] 12. Mood tracker: symptoms chips + period cycle prediction
[ ] 13. CachedNetworkImage replacing CrossPlatformImage
[ ] 14. Pagination + pull to refresh on all feeds
[ ] 15. Shimmer loading + Lottie empty states
[ ] 16. Firestore security rules
```
