import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuth settings
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gradient_background.dart';
import '../widgets/utelo_logo.dart';
import '../widgets/country_code_picker.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import 'otp_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  String _countryCode = '+91';
  bool _isNewUser = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Bypass Play Integrity/ReCaptcha on Emulators in Debug Mode
    // Bypass Play Integrity/ReCaptcha on Emulators in Debug Mode
    // COMMENTED OUT: We now have SHA keys, so we WANT Play Integrity to run.
    /* if (kDebugMode) {
        debugPrint('DEBUG MODE: Disabling app verification for testing');
        FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
    } */
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.light),
      child: Scaffold(
        body: GradientBackground(
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                  
                  // Logo
                  const UteloLogo(
                    logoSize: 120,
                    fontSize: 36,
                    textColor: Colors.black87,
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Enter mobile number text
                  Text(
                    'Enter your Mobile Number',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Phone number input with country code
                  Form(
                    key: _formKey,
                    child: CountryCodePicker(
                      initialCode: _countryCode,
                      phoneController: _phoneController,
                      onCodeChanged: (code) {
                        _countryCode = code;
                      },
                      hintText: 'Mobile Number',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your mobile number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid mobile number';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // New user checkbox
                  const SizedBox(height: 10),
                  
                  const SizedBox(height: 10),
                  
                  // Next button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              'Next',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
  
  void _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String phoneNumber = '$_countryCode ${_phoneController.text.trim()}';

      await _localStorage.savePhoneNumber(phoneNumber);

      // Safety timer to prevent infinite loading
      final safetyTimer = Future.delayed(const Duration(seconds: 70), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request timed out. Please check your internet connection and Firebase configuration.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        codeSent: (String verificationId, int? resendToken) {
          // Cancel safety timer is not really possible with Future.delayed but 
          // _isLoading check prevents side effects
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPScreen(
                  phoneNumber: phoneNumber,
                  verificationId: verificationId,
                  isNewUser: _isNewUser,
                ),
              ),
            );
          }
        },
        verificationFailed: (String errorMessage) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        verificationCompleted: (credential) async {
          // Auto-verification completed
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Auto retrieval timeout');
        },
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
