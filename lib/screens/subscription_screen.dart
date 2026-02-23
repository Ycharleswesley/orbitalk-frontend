import 'package:flutter/material.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/razorpay_service.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentIndex = 0;

  final RazorpayService _razorpayService = RazorpayService();
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  
  String _userName = 'User';
  String _phoneNumber = '9999999999';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _razorpayService.init();
    _razorpayService.onSuccess = (orderId, paymentId) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Successful! ID: $paymentId')));
    };
    _razorpayService.onFailure = (message) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $message')));
    };
  }

  Future<void> _loadUserData() async {
    final cachedName = await _localStorage.getUserName();
    final cachedPhone = await _localStorage.getPhoneNumber();
    if (mounted) {
      setState(() {
        _userName = cachedName ?? 'User';
        _phoneNumber = cachedPhone ?? '9999999999';
      });
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _packs = [
    {
      'id': 'gold',
      'amount': 999.0,
      'name': 'Gold Pack',
      'price': '₹999/month',
      'colors': [const Color(0xFFFFD700), const Color(0xFFFFE600), const Color(0xFFD4AF37), const Color(0xFFFFD700)],
      'shadowColor': const Color(0xFFAA8800),
      'image': 'assets/images/badge_gold_v2.png', 
      'features': ['VIP Support', 'Unlimited Calls', 'Ad-Free'],
    },
    {
      'id': 'silver',
      'amount': 499.0,
      'name': 'Silver Pack',
      'price': '₹499/month',
      'colors': [const Color(0xFFC0C0C0), const Color(0xFFE0E0E0), const Color(0xFFA9A9A9), const Color(0xFFC0C0C0)],
      'shadowColor': const Color(0xFF707070),
      'image': 'assets/images/badge_silver_v2.png', 
      'features': ['Priority Support', '500 mins/mo', 'No Ads'],
    },
    {
      'id': 'bronze',
      'amount': 199.0,
      'name': 'Bronze Pack',
      'price': '₹199/month',
      'colors': [const Color(0xFFCD7F32), const Color(0xFFFFC085), const Color(0xFF8B4513), const Color(0xFFCD7F32)],
      'shadowColor': const Color(0xFF8B4513),
      'image': 'assets/images/badge_bronze_v2.png', 
      'features': ['Standard Support', '100 mins/mo', 'Basic Features'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to show Mesh
      body: MeshGradientBackground(
        isDark: true, // Force Dark Mesh Theme as requested
        child: SafeArea(
          child: Column(
            children: [
               // Header with Crown Logo and 'UPGRADE TO UTELO'
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.withOpacity(0.1),
                            ),
                            child: Image.asset(
                              'assets/images/crown_icon.png',
                              width: 35,
                              height: 35,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 10),
                           Text(
                            "UPGRADE TO UTELO",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Unlock premium features today",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _packs.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildSubscriptionCard(_packs[index], index == _currentIndex);
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _packs.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 12 : 8,
                    height: _currentIndex == index ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? _packs[index]['colors'][0] : Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
               // Close Button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> pack, bool isActive) {
    final List<Color> gradientColors = pack['colors'];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      // Adjust margins to prevent cutoff: vertical margin is crucial here
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: isActive ? 10 : 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Shiny Metallic Gradient
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.3, 0.6, 1.0], 
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (pack['shadowColor'] as Color).withOpacity(0.5),
                  blurRadius: 25,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
        border: Border.all(
             color: Colors.white.withOpacity(0.6), 
             width: 1.5
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                 // Rank Badge Image
                Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.3),
                         blurRadius: 20,
                         offset: const Offset(0, 10),
                       )
                    ]
                  ),
                  child: Image.asset(
                    pack['image'],
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  pack['name'],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(offset: Offset(1,1), blurRadius: 4, color: Colors.black45)
                    ]
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                     color: Colors.black.withOpacity(0.15),
                     borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(
                    pack['price'],
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            // Features
            Column(
              children: pack['features'].map<Widget>((feature) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // 3D Button
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE0E0E0)], // Silver/White 3D look
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 4),
                    blurRadius: 5,
                  )
                ]
              ),
              child: ElevatedButton(
                onPressed: () {
                   _razorpayService.checkoutPackage(
                     packageId: pack['id'],
                     expectedAmount: pack['amount'],
                     testKeyId: "rzp_test_SHh8evyVGnafPT", // Test Key ID
                     name: _userName,
                     description: "Payment for ${pack['name']}",
                     userEmail: "test@example.com",
                     userContact: _phoneNumber,
                   );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: pack['shadowColor'],
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  "BUY NOW",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
