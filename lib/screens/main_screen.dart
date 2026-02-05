import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/call_service.dart';
import 'chats_screen.dart';
import 'calls_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final GlobalKey<ChatsScreenState> _chatsScreenKey = GlobalKey<ChatsScreenState>();
  final GlobalKey<CallsScreenState> _callsScreenKey = GlobalKey<CallsScreenState>();
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final CallService _callService = CallService();
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(true);
    _ensureCallListener();
    _screens = [
      ChatsScreen(key: _chatsScreenKey),
      CallsScreen(key: _callsScreenKey),
      const SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _ensureCallListener();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      await _authService.updateOnlineStatus(isOnline);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Future<void> _ensureCallListener() async {
    try {
      String? userId = _authService.currentUserId;
      userId ??= await _localStorage.getUserId();
      if (userId != null) {
        debugPrint('MainScreen: Starting call listener for $userId');
        _callService.startListeningForIncomingCalls(userId);
      } else {
        debugPrint('MainScreen: No userId available for call listener.');
      }
    } catch (e) {
      debugPrint('MainScreen: Failed to start call listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: _selectedIndex == 0 
              ? Colors.blue 
              : (_selectedIndex == 1 ? Colors.green : Colors.grey),
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.call_outlined),
              activeIcon: Icon(Icons.call),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_selectedIndex == 0) {
                  // New chat - call the dialog from ChatsScreen
                  _chatsScreenKey.currentState?.showNewChatDialog();
                } else if (_selectedIndex == 1) {
                  // New call - call the dialog from CallsScreen
                  _callsScreenKey.currentState?.showNewCallDialog();
                }
              },
              backgroundColor: Colors.purple.shade600,
              child: Icon(
                _selectedIndex == 0 ? Icons.message : Icons.add_call,
                color: Colors.white,
              ),
            ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
