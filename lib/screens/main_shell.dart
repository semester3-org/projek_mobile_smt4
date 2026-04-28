import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'chat/chat_booking_page.dart';
import 'favorites/favorites_page.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';

/// Shell utama: BottomNavigationBar + state favorit global sederhana.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<String> _favoriteKosIds = {};

  void _toggleFavorite(String kosId) {
    setState(() {
      if (_favoriteKosIds.contains(kosId)) {
        _favoriteKosIds.remove(kosId);
      } else {
        _favoriteKosIds.add(kosId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state tiap tab (beranda, favorit, chat, profil).
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            favoriteKosIds: _favoriteKosIds,
            onToggleFavorite: _toggleFavorite,
          ),
          FavoritesPage(
            favoriteKosIds: _favoriteKosIds,
            onToggleFavorite: _toggleFavorite,
          ),
          const ChatBookingPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
