import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gradient_background.dart';
import '../widgets/utelo_logo.dart';
import '../utils/app_colors.dart';
import '../services/local_storage_service.dart';
import 'main_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String userName;
  final String selectedLanguage;
  final String userId;
  
  const WelcomeScreen({
    Key? key,
    required this.userName,
    required this.selectedLanguage,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                
                // Logo
                const UteloLogo(
                  logoSize: 150,
                  fontSize: 40,
                  textColor: Colors.black87,
                ),
                
                const SizedBox(height: 60),
                
                // Welcome message
                Text(
                  'Enjoy messaging with your',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
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
                  'preferred language.',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
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
                
                const Spacer(),
                
                // Start Messaging button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final localStorage = LocalStorageService();
                      await localStorage.saveUserId(userId);
                      await localStorage.saveUserName(userName);
                      await localStorage.saveLanguage(selectedLanguage);
                      
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Start Messaging',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
