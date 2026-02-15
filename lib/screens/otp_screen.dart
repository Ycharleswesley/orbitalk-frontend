import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/mesh_gradient_background.dart'; // Updated
import '../widgets/glassmorphic_card.dart'; // Updated
import '../widgets/utelo_logo.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final bool isNewUser;
  
  const OTPScreen({
    Key? key,
    required this.phoneNumber,
    required this.verificationId,
    this.isNewUser = false,
  }) : super(key: key);

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _onOTPDigitChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field
      _focusNodes[index - 1].requestFocus();
    }
    
    // Check if all fields are filled
    if (_otpControllers.every((controller) => controller.text.length == 1)) {
      _submitOTP();
    }
  }

  void _submitOTP() async {
    String otp = _otpControllers.map((c) => c.text).join();
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.verifyOTP(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (userCredential != null) {
        final userId = userCredential.user!.uid;
        
        // Check if user profile exists
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists || widget.isNewUser) {
          // New user: go to signup flow
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SignupScreen(
                  userId: userId,
                  phoneNumber: widget.phoneNumber,
                ),
              ),
            );
          }
        } else {
          // Existing user: go to main screen
          // Save user ID to local storage
          await _localStorage.saveUserId(userId);
          
          final userData = userDoc.data() as Map<String, dynamic>;
          final userName = userData['name'] as String?;
          final profilePicture = userData['profilePicture'] as String?;
          final phoneNumber = userData['phoneNumber'] as String?;
          
          if (userName != null) {
            await _localStorage.saveUserName(userName);
          }
          if (profilePicture != null) {
            await _localStorage.saveProfilePicture(profilePicture);
          }
          if (phoneNumber != null) {
            await _localStorage.savePhoneNumber(phoneNumber);
          }
          
          await _authService.updateOnlineStatus(true);
          
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid OTP. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: MeshGradientBackground(
          isDark: false, // Light Mode
          child: SafeArea(
            child: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassmorphicCard(
                  blur: 20,
                  opacity: 0.6,
                  color: const Color(0xFFE3F2FD), // Light Blue Tint
                  borderRadius: 30,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Utelo Logo
                      const UteloLogo(
                        logoSize: 100,
                        fontSize: 28,
                        textColor: Colors.black87,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // OTP text
                      Text(
                        'Enter OTP sent to your number',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        widget.phoneNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // OTP input boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 40,
                            height: 50,
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: const Color(0xFF00C853), // Green Theme
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) => _onOTPDigitChanged(value, index),
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Submit button (Green)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853), // Green Button
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Submit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Resend OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive OTP? ",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('OTP resent successfully'), backgroundColor: Colors.green),
                              );
                            },
                            child: Text(
                              'Resend',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6C63FF),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
