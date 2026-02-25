import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis_auth/auth_io.dart' as googleauth;
import 'package:http/http.dart' as http;
import 'package:webrtc_app/core/constants/service_account.dart';
import 'package:webrtc_app/features/notification/model/app_notification.dart';

// ── Notification Service ───────────────────────────────────────────────────

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _messaging = FirebaseMessaging.instance;

  static const _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/webrtc-app-8a1f1/messages:send';

  // ── Initialize — call once on app start after auth ────────────────────────

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('✅ Notification permission granted');
      // await saveToken();
    } else {
      log('❌ Notification permission denied');
    }

    // Refresh token when it changes
    _messaging.onTokenRefresh.listen((newToken) {
      _updateToken(newToken);
    });

    // Foreground message received
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📩 Foreground: ${message.notification?.title}');
    });

    // Notification tapped from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('📩 Tapped: ${message.notification?.title}');
    });

    // App opened from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      log(
        '📩 Launched from notification: ${initialMessage.notification?.title}',
      );
    }
  }

  // ── Save FCM token to users/{uid} ─────────────────────────────────────────

  Future<void> saveToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
    log('✅ FCM token saved for $uid');
  }

  /*  Future<String?> saveTokenTest() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final token = await _messaging.getToken();
    return token;
    /*   if (token == null) return;
    await _firestore.collection('users').doc(uid).update({'fcmToken': token}); */
    log('✅ FCM token saved for $uid');
  } */

  Future<void> _updateToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  // ── Get access token — same approach as szaman_chat ──────────────────────

  Future<String> _getAccessToken() async {
    final serviceAccountJson = ServiceAccount.json;
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await googleauth.clientViaServiceAccount(
      googleauth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );

    final credentials = await googleauth
        .obtainAccessCredentialsViaServiceAccount(
          googleauth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client,
        );

    client.close();
    return credentials.accessToken.data;
  }

  // ── Send to single user ───────────────────────────────────────────────────

  Future<void> sendToUser({
    required String recipientUid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final myUid = _auth.currentUser?.uid;
      if (recipientUid == myUid) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(recipientUid)
          .get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null) {
        log('⚠️ No FCM token for $recipientUid');
        return;
      }

      final accessToken = await _getAccessToken();

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'data': {
              'uid': recipientUid,
            }, //{'click_action': 'FLUTTER_NOTIFICATION_CLICK', ...?data},
            /*  'android': {
              'priority': 'high',
              'notification': {'sound': 'default', 'priority': 'high'},
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1},
              },
            }, */
          },
        }),
      );

      if (response.statusCode == 200) {
        log('✅ Push sent to $recipientUid');
        await _storeNotification(
          uid: recipientUid,
          title: title,
          body: body,
          data: data,
        );
      } else {
        log('❌ Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      log('sendToUser error: $e');
    }
  }

  Future<void> sendToUserTest() async {
    try {
      final recipientUid = "IsB7wkfMiFPoZHDyDg0XC1Onq9E3";

      final userDoc = await _firestore
          .collection('users')
          .doc(recipientUid)
          .get();
      final fcmToken =
          "dzBDcnNgTTWGukujPkkf4e:APA91bF4UA5k-vIrrW5xllFjnMwP5jQjrV98jTx5k3lhKPyX7xfYfYDaCGX0d2isGnZxFS4l_TRoRTXKSw6HlxfyoHWeN5Uzm3R-IYRaYyoMUEsqL54GNY8";
      print("accessToken started");
      final accessToken = await _getAccessToken();
      print("accessToken:$accessToken");

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': "test Title", 'body': "testBody"},
            'data': {
              'uid': recipientUid,
            }, //{'click_action': 'FLUTTER_NOTIFICATION_CLICK', ...?data},
            /*  'android': {
              'priority': 'high',
              'notification': {'sound': 'default', 'priority': 'high'},
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1},
              },
            }, */
          },
        }),
      );

      if (response.statusCode == 200) {
        log('✅ Push sent to $recipientUid');
        await _storeNotification(
          uid: recipientUid,
          title: "title",
          body: "body",
          data: {},
        );
      } else {
        log('❌ Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      log('sendToUser error: $e');
    }
  }

  // ── Send to multiple users (room members) ────────────────────────────────

  Future<void> sendToUsers({
    required List<String> recipientUids,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final myUid = _auth.currentUser?.uid;
    await Future.wait(
      recipientUids
          .where((uid) => uid != myUid)
          .map(
            (uid) => sendToUser(
              recipientUid: uid,
              title: title,
              body: body,
              data: data,
            ),
          ),
    );
  }

  // ── Store notification in Firestore ──────────────────────────────────────

  Future<void> _storeNotification({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'data': data ?? {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // ── Mark as read ──────────────────────────────────────────────────────────

  Future<void> markAsRead(String notificationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final unread = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<int> unreadCountStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<List<AppNotification>> notificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => AppNotification.fromDoc(d)).toList(),
        );
  }
}

final unreadCountProvider = StreamProvider<int>((ref) {
  return NotificationService.instance.unreadCountStream();
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return NotificationService.instance.notificationsStream();
});
