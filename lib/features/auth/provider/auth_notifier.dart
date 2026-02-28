import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:webrtc_app/features/auth/model/auth_state.dart';
import 'package:webrtc_app/features/auth/model/user_model.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  AuthNotifier() : super(AuthState.initial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Fetch name from Firestore since we use anonymous auth
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final name = doc.data()?['name'] ?? 'User';
      final loginId = doc.data()?['loginId'] ?? '';

      state = AuthState.authenticated(
        UserModel(id: user.uid, name: name, loginId: loginId),
      );
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    if (loginId.isEmpty || password.isEmpty) {
      state = AuthState.error('Please fill in all fields');
      return;
    }

    try {
      state = AuthState.loading();

      // Reuse existing session if available
      User? user = _auth.currentUser;
      if (user == null) {
        final credential = await _auth.signInAnonymously();
        user = credential.user!;
      }

      // Store name in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'name': loginId,
        'loginId': loginId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = AuthState.authenticated(
        UserModel(id: user.uid, name: loginId, loginId: loginId),
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState.error(e.message ?? 'An error occurred');
    } catch (e) {
      state = AuthState.error('Login failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
