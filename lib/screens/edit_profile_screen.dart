import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/local_storage_service.dart';
import '../utils/app_colors.dart';
import '../widgets/curved_header.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentProfilePicture;
  final String userId;

  const EditProfileScreen({
    Key? key,
    required this.currentName,
    required this.currentProfilePicture,
    required this.userId,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  String? _profilePictureUrl;
  int _selectedColorId = 0; // Default Blue
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _profilePictureUrl = widget.currentProfilePicture;
    _loadCurrentColor();
  }

  Future<void> _loadCurrentColor() async {
     final colorId = await LocalStorageService().getProfileColor();
     if (mounted) {
       setState(() {
         _selectedColorId = colorId;
       });
     }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        uploadedImageUrl = await _storageService.uploadProfilePicture(
          _selectedImage!,
          widget.userId,
        );
      }

      // Update profile in Firestore (Including Color!)
      await _authService.updateUserProfile(
        userId: widget.userId,
        name: _nameController.text.trim(),
        profilePicture: uploadedImageUrl ?? _profilePictureUrl,
        profileColor: _selectedColorId, 
      );
      
      // Save locally
      await LocalStorageService().saveProfileColor(_selectedColorId);

      if (uploadedImageUrl != null) {
        setState(() {
          _profilePictureUrl = uploadedImageUrl;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0141B5), width: 3),
            ),
            child: ClipOval(
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    )
                  : _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                      ? Image.network(
                          _profilePictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildInitialsAvatar();
                          },
                        )
                      : _buildInitialsAvatar(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF001133), // Deep Blue
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final name = _nameController.text.trim();
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
        : '?';

    return Container(
      color: AppColors.getColor(_selectedColorId),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Theme Color',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: AppColors.profileColors.map((colorMap) {
             final int id = colorMap['id'];
             final List<Color> gradientColors = colorMap['gradient']; // Use gradient list
             final bool hasImage = _selectedImage != null || (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty);
             final bool isSelected = id == _selectedColorId && !hasImage;
             
             return GestureDetector(
               onTap: () {
                 setState(() {
                   _selectedColorId = id;
                   _selectedImage = null;
                   _profilePictureUrl = '';
                 });
               },
               child: Container(
                 width: 50,
                 height: 50,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                   ),
                   border: isSelected 
                      ? Border.all(color: Colors.black87, width: 3)
                      : Border.all(color: Colors.transparent, width: 3),
                   boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                   ],
                 ),
                 child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
               ),
             );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade50;
    
    return Scaffold(
      backgroundColor: bgColor, 
      body: Stack(
        children: [
          // Content
          ClipRect(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 260, 24, 24), // Push content down
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile Picture
                  _buildProfileImage(),
                  
                  const SizedBox(height: 12),
                  
                  Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.edit, size: 18, color: isDark ? Colors.blue : const Color(0xFF001133)),
                  label: Text(
                    'Change Photo',
                    style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.blue : const Color(0xFF001133)),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.blue : const Color(0xFF001133),
                  ),
                ),
              ),
                  
                  const SizedBox(height: 32),
                  
                  // Name Field
                  Text(
                    'Name',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(
                       fontSize: 15,
                       color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // COLOR PICKER
                  _buildColorPicker(),
                  
                  const SizedBox(height: 40),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF0141B5) : const Color(0xFF001133),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
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
          
          // Header
         Positioned(
            top: 0, left: 0, right: 0,
            child: CurvedHeader(
              showBack: true,
              onBackPressed: () => Navigator.pop(context),
              titleWidget: Text(
                'Edit Profile',
                style: GoogleFonts.poppins(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
