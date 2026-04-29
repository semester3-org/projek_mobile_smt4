import 'package:flutter/material.dart';

import 'cafe/cafe_page.dart';
import 'catering/catering_page.dart';
import 'laundry/laundry_page.dart';
import 'profile/notification_list_page.dart';
import 'profile/profile_page.dart';
import 'user/user_home_page.dart';
import 'user/user_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          UserHomePage(onSelectTab: _selectTab),
          const LaundryPage(),
          const CateringPage(),
          const CafePage(),
          const NotificationListPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [UserTheme.softShadow(opacity: 0.09)],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _selectTab,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: UserTheme.primary,
            unselectedItemColor: const Color(0xFF94A3B8),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_laundry_service_outlined),
                activeIcon: Icon(Icons.local_laundry_service_rounded),
                label: 'Laundry',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_outlined),
                activeIcon: Icon(Icons.restaurant_rounded),
                label: 'Catering',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_cafe_outlined),
                activeIcon: Icon(Icons.local_cafe_rounded),
                label: 'Kafe',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_none_rounded),
                activeIcon: Icon(Icons.notifications_rounded),
                label: 'Notifikasi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
