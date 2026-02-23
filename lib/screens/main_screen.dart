import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/call_service.dart';
import 'chats_screen.dart';
import 'calls_screen.dart';
import 'settings_screen.dart';
import 'contacts_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 1; // Default to Chats
  late PageController _pageController; // Controller for PageView
  final GlobalKey<ChatsScreenState> _chatsScreenKey = GlobalKey<ChatsScreenState>();
  final GlobalKey<CallsScreenState> _callsScreenKey = GlobalKey<CallsScreenState>();
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final CallService _callService = CallService();
  StreamSubscription<User?>? _authSubscription;
  Timer? _onlinePingTimer;
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1); // FORCE 1
    WidgetsBinding.instance.addObserver(this);
    
    // Safety Force Jump
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _pageController.page != 1.0) {
        debugPrint('MainScreen: Forcing jump to Chats (Index 1)');
        _pageController.jumpToPage(1);
      }
    });

    _setOnlineStatus(true);
    _startOnlinePing();
    _ensureCallListener();
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        debugPrint('MainScreen: Auth restored, starting call listener for ${user.uid}');
        _callService.startListeningForIncomingCalls(user.uid);
        await _authService.syncFcmToken();
      }
    });
      _screens = [
      const ContactsScreen(),
      ChatsScreen(key: _chatsScreenKey),
      CallsScreen(key: _callsScreenKey),
      const SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose Controller
    WidgetsBinding.instance.removeObserver(this);
    _stopOnlinePing();
    _setOnlineStatus(false);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _startOnlinePing() {
    _onlinePingTimer?.cancel();
    _onlinePingTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _setOnlineStatus(true);
    });
  }

  void _stopOnlinePing() {
    _onlinePingTimer?.cancel();
    _onlinePingTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _startOnlinePing();
      _ensureCallListener();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive || 
               state == AppLifecycleState.detached || 
               state == AppLifecycleState.hidden) {
      _setOnlineStatus(false);
      _stopOnlinePing();
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      await _authService.updateOnlineStatus(isOnline);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Future<void> _ensureCallListener({int retryCount = 0}) async {
    try {
      String? userId = _authService.currentUserId;
      userId ??= await _localStorage.getUserId();
      if (userId != null) {
        debugPrint('MainScreen: Starting call listener for $userId');
        _callService.startListeningForIncomingCalls(userId);
      } else if (retryCount < 3) {
        debugPrint('MainScreen: No userId yet. Retrying call listener in 1s...');
        Future.delayed(const Duration(seconds: 1), () {
          _ensureCallListener(retryCount: retryCount + 1);
        });
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
      backgroundColor: Colors.transparent, // Transparent to show Mesh
      extendBody: true, // Allow body to extend behind Nav Bar
      body: MeshGradientBackground(
        isDark: isDark,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          physics: const NeverScrollableScrollPhysics(), // Disabled manual swiping
          children: _screens,
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              // High Contrast: Use Dark Blue for both Light and Dark modes
              color: isDark ? const Color(0xFF001133).withOpacity(0.6) : const Color(0xFF001133).withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF001133).withOpacity(0.5),
                        const Color(0xFF0141B5).withOpacity(0.5),
                      ]
                    : [
                        const Color(0xFF001133).withOpacity(0.6), // Dark Blue
                        const Color(0xFF0141B5).withOpacity(0.4), // Lighter Deep Blue
                      ],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
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
                  icon: Icon(Icons.contacts_outlined),
                  activeIcon: Icon(Icons.contacts),
                  label: 'Contacts',
                ),
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
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  // Refined FAB Logic
  Widget? _buildFloatingActionButton(bool isDark) {
    if (_selectedIndex == 3) return null; // Settings (no FAB)

    return FloatingActionButton(
      onPressed: () async {
         if (_selectedIndex == 0) {
            try {
               await FlutterContacts.openExternalInsert();
            } catch (e) {
               debugPrint('Error opening contact insertion: $e');
            }
         } else if (_selectedIndex == 1) {
            _chatsScreenKey.currentState?.showNewChatDialog();
         } else if (_selectedIndex == 2) {
            _callsScreenKey.currentState?.showNewCallDialog();
         }
      },
      backgroundColor: isDark ? const Color(0xFF0141B5) : const Color(0xFF001133),
      child: Icon(
        _selectedIndex == 0 
           ? Icons.person_add 
           : (_selectedIndex == 1 ? Icons.message : Icons.add_call),
        color: Colors.white,
      ),
    );
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }
}
