import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if current Firebase user has verified email
  Future<bool> isCurrentUserEmailVerified({bool reload = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    if (reload) {
      await user.reload();
    }

    return _auth.currentUser?.emailVerified ?? user.emailVerified;
  }

  /// Send verification email to current Firebase user
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No signed-in user found for email verification.';
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign up with email and password
  Future<UserModel?> signup({
    required String email,
    required String username,
    required String displayName,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Create UserModel
        final userModel = UserModel(
          id: user.uid,
          username: username,
          displayName: displayName,
          email: email,
          createdAt: DateTime.now(),
          isPublic: true,
        );
        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
    return null;
  }

  /// Login with email and password
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Return basic user info from Auth
        return UserModel(
          id: user.uid,
          username: email.split('@')[0], // Fallback username from email
          displayName: user.displayName ?? email,
          email: user.email ?? email,
          createdAt: DateTime.now(),
          isPublic: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
    return null;
  }

  /// Logout the current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Reset password with email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.updateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'The password is incorrect.';
      case 'invalid-credential':
        return 'The credentials are invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An unknown error occurred: ${e.message}';
    }
  }
}
