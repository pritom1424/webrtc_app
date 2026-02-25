import 'package:flutter/material.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';
import 'package:webrtc_app/core/widgets/app_drawer.dart';
import 'package:webrtc_app/features/notification/screen/notification_screen.dart';
import 'package:webrtc_app/features/notification/widgets/notification_badge.dart';
import 'package:webrtc_app/features/p2p/screen/user_list_screen.dart';
import 'package:webrtc_app/features/profile/screen/profile_screen.dart';
import 'package:webrtc_app/features/rooms/screen/roomlist_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int currentNavIndex = 0;
  List<Widget> screens = [
    RoomListScreen(),
    UserListScreen(),
    NotificationScreen(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("BDCOM"),
            Text(
              'Connecting Progress',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      drawer: AppDrawer(),
      body: screens[currentNavIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentNavIndex,
        onTap: (value) => setState(() {
          currentNavIndex = value;
        }),
        items: [
          BottomNavigationBarItem(
            backgroundColor: AppColors.primaryBlue,
            icon: Icon(Icons.meeting_room),
            label: "room",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "message"),
          BottomNavigationBarItem(
            icon: NotificationBadge(child: Icon(Icons.notifications)),
            label: "notification",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "profile"),
        ],
      ),
    );
  }
}
