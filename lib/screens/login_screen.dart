import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/glassmorphic_card.dart';
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
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glassmorphic Card (Blue Theme)
                    GlassmorphicCard(
                      blur: 20,
                      opacity: 0.6,
                      color: const Color(0xFFE3F2FD), // Light Blue Tint
                      borderRadius: 30,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Text(
                            'CUSTOMER LOGIN',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                          
                          const SizedBox(height: 40),

                          // Phone Input Area (Minimal)
                          Container(
                            child: Form(
                              key: _formKey,
                              child: CountryCodePicker(
                                initialCode: _countryCode,
                                phoneController: _phoneController,
                                isMinimal: true,
                                onCodeChanged: (code) {
                                  _countryCode = code;
                                },
                                hintText: 'Mobile Number',
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Enter mobile number';
                                  if (value.length < 10) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Terms & Conditions Checkbox
                           Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: const Color(0xFF00C853),
                                  onChanged: _isLoading ? null : (value) {
                                    setState(() {
                                      _agreedToTerms = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isLoading) {
                                      setState(() {
                                        _agreedToTerms = !_agreedToTerms;
                                      });
                                    }
                                  },
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'I agree to the ',
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                                      children: [
                                        TextSpan(
                                          text: 'Terms and Conditions',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                            color: const Color(0xFF6C63FF),
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = _showTermsDialog,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 30),

                          // Login Button (Green) - Disabled if T&C not checked
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isLoading || !_agreedToTerms) ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C853), // Green Button
                                disabledBackgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: _agreedToTerms ? 5 : 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'LOGIN',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                     // Footer Text
                    Text(
                      'Powered by UTELO',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms & Privacy Policy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terms of Use', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('In General\nUTELO (Universal Translation & Easy Language Output), is a product owned by LINKUP COMMUNICATION PVT LTD. This document governs your relationship with UTELO. Access to and use of this UTELO and its services available through Google Play store (collectively, the "Services") are subject to the following terms, conditions and notices (the "Terms of Service"). By using the Services, you are agreeing to all the Terms of Service, as may be updated by us from time to time.\n\nAccess to UTELO is permitted on a temporary basis, and we reserve the right to withdraw or amend the Services without notice. We will not be liable if for any reason this UTELO is unavailable at any time or for any period.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Privacy Policy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Our privacy policy, which sets out how we will use your information, can be found below. By using this UTELO, you consent to the processing described therein and warrant that all data provided by you is accurate.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Prohibitions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('You must not misuse UTELO You will not: commit or encourage a criminal offense; transmit or distribute a virus, trojan, worm, logic bomb or any other material which is malicious, technologically harmful, in breach of confidence or in any way offensive or obscene; hack into any aspect of the Service; corrupt data; cause annoyance to other users; infringe upon the rights of any other person\'s proprietary rights; send any unsolicited advertising or promotional material, commonly referred to as "spam".', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Intellectual Property', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('The intellectual property rights in all software and content remains the property of LINKUP COMMUNICATION PVT LTD or its licensors and are protected by copyright laws.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Disclaimer of Liability', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('The material displayed on UTELO is provided without any guarantees, conditions or warranties as to its accuracy. LINKUP COMMUNICATION PVT LTD expressly excludes all conditions, warranties and other terms which might otherwise be implied by statute, common law or the law of equity.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('Privacy Policy (Detailed)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Privacy Policy governs the way UTELO collects, uses, maintains and discloses information collected from users. This privacy policy applies to the UTELO, and its services offered by LINKUP COMMUNICATION PVT LTD.\n\nUTELO may collect personal identification information from Users in a variety of ways, including, but not limited to, when Users visit our UTELO, register on the UTELO. Users may be asked for, as appropriate, name, email address, phone number. We will collect personal identification information from Users only if they voluntarily submit such information to us.\n\nUTELO may collect and use Users personal information to improve customer service, improve our UTELO, run features, and send periodic emails.\n\nUTELO adopts appropriate data collection, storage and processing practices and security measures to protect again, transaction information and data stored on our UTELO. Sensitive and private data exchange happens over an SSL secured communication channel.', style: GoogleFonts.poppins(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.black)),
          ),
        ],
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

      final safetyTimer = Future.delayed(const Duration(seconds: 70), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request timed out. Please check internet.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        codeSent: (String verificationId, int? resendToken) {
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
