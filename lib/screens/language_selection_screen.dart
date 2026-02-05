import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gradient_background.dart';
import '../widgets/utelo_logo.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String userName;
  final String userId;
  
  const LanguageSelectionScreen({
    Key? key,
    required this.userName,
    required this.userId,
  }) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  final List<Map<String, String>> languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Marathi', 'code': 'mr'},
    {'name': 'Bengali', 'code': 'bn'},
    {'name': 'Tamil', 'code': 'ta'},
    {'name': 'Telugu', 'code': 'te'},
    {'name': 'Malayalam', 'code': 'ml'},
    {'name': 'Kannada', 'code': 'kn'},
    {'name': 'Punjabi', 'code': 'pa'},
    {'name': 'Gujarati', 'code': 'gu'},
    {'name': 'Urdu', 'code': 'ur'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = 'en'; // Default to English
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    logoSize: 100,
                    fontSize: 32,
                    textColor: Colors.black87,
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Select language text
                  Text(
                    'Select your preferred translating',
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
                  Text(
                    'language',
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
                  
                  // Language dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      underline: const SizedBox(),
                      hint: Text(
                        'Select Language',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade700,
                        size: 30,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                      },
                      items: languages.map<DropdownMenuItem<String>>((lang) {
                        return DropdownMenuItem<String>(
                          value: lang['code'],
                          child: Text(
                            lang['name']!,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Next button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedLanguage != null && !_isLoading)
                          ? _saveLanguageAndContinue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonColor,
                        disabledBackgroundColor: AppColors.buttonColor.withOpacity(0.5),
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
    );
  }

  void _saveLanguageAndContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update user profile with language
      await _authService.createOrUpdateUserProfile(
        uid: widget.userId,
        language: _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(
              userName: widget.userName,
              selectedLanguage: _selectedLanguage!,
              userId: widget.userId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
