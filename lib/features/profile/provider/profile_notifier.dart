import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:webrtc_app/features/auth/model/user_model.dart';
import 'package:webrtc_app/features/profile/model/profile_state.dart';

class ProfileNotifier extends StateNotifier<ProfileState> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  ProfileNotifier() : super(ProfileState.initial()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      state = ProfileState.loading(state.user);

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final user = UserModel.fromDoc(doc);
      state = ProfileState.success(user, '');
    } catch (e) {
      log('loadProfile error: $e');
      state = ProfileState.error(state.user, 'Failed to load profile');
    }
  }

  Future<void> updateName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      state = ProfileState.error(state.user, 'Name cannot be empty');
      return;
    }
    if (trimmed == state.user?.name) {
      state = ProfileState.error(state.user, 'Name is the same as current');
      return;
    }
    if (trimmed.length < 2) {
      state = ProfileState.error(
        state.user,
        'Name must be at least 2 characters',
      );
      return;
    }
    if (trimmed.length > 30) {
      state = ProfileState.error(
        state.user,
        'Name must be under 30 characters',
      );
      return;
    }

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      state = ProfileState.loading(state.user);

      // Single update — reflects everywhere since all screens fetch from users/{uid}
      await _firestore.collection('users').doc(uid).update({
        'name': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedUser =
          state.user?.copyWith(name: trimmed) ??
          UserModel(id: uid, name: trimmed, loginId: trimmed);

      state = ProfileState.success(updatedUser, 'Name updated successfully');
    } catch (e) {
      log('updateName error: $e');
      state = ProfileState.error(state.user, 'Failed to update name');
    }
  }

  Future<void> updateLoginId(String newLoginId) async {
    final trimmed = newLoginId.trim();
    if (trimmed.isEmpty) {
      state = ProfileState.error(state.user, 'Login ID cannot be empty');
      return;
    }
    if (trimmed == state.user?.loginId) {
      state = ProfileState.error(state.user, 'Login ID is the same as current');
      return;
    }
    if (trimmed.length < 3) {
      state = ProfileState.error(
        state.user,
        'Login ID must be at least 3 characters',
      );
      return;
    }

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      state = ProfileState.loading(state.user);

      // Check if loginId already taken
      final existing = await _firestore
          .collection('users')
          .where('loginId', isEqualTo: trimmed)
          .get();

      if (existing.docs.isNotEmpty && existing.docs.first.id != uid) {
        state = ProfileState.error(state.user, 'Login ID already taken');
        return;
      }

      await _firestore.collection('users').doc(uid).update({
        'loginId': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedUser = state.user?.copyWith(loginId: trimmed);
      if (updatedUser != null) {
        state = ProfileState.success(
          updatedUser,
          'Login ID updated successfully',
        );
      }
    } catch (e) {
      log('updateLoginId error: $e');
      state = ProfileState.error(state.user, 'Failed to update Login ID');
    }
  }

  void clearMessages() {
    if (state.user != null) {
      state = ProfileState.success(state.user!, '');
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(),
);
