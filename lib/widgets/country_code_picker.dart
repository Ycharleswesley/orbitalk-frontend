import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CountryCodePicker extends StatefulWidget {
  final String initialCode;
  final Function(String) onCodeChanged;
  final TextEditingController phoneController;
  final String? Function(String?)? validator;
  final String hintText;
  final bool showFlag;

  const CountryCodePicker({
    Key? key,
    this.initialCode = '+91',
    required this.onCodeChanged,
    required this.phoneController,
    this.validator,
    this.hintText = 'Mobile Number',
    this.showFlag = true,
  }) : super(key: key);

  @override
  State<CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<CountryCodePicker> {
  late String _selectedCode;

  static const List<Map<String, String>> countryCodes = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA/Canada', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+82', 'name': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+7', 'name': 'Russia', 'flag': '🇷🇺'},
    {'code': '+55', 'name': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+34', 'name': 'Spain', 'flag': '🇪🇸'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+31', 'name': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+41', 'name': 'Switzerland', 'flag': '🇨🇭'},
    {'code': '+46', 'name': 'Sweden', 'flag': '🇸🇪'},
    {'code': '+47', 'name': 'Norway', 'flag': '🇳🇴'},
    {'code': '+45', 'name': 'Denmark', 'flag': '🇩🇰'},
    {'code': '+358', 'name': 'Finland', 'flag': '🇫🇮'},
    {'code': '+48', 'name': 'Poland', 'flag': '🇵🇱'},
    {'code': '+43', 'name': 'Austria', 'flag': '🇦🇹'},
    {'code': '+32', 'name': 'Belgium', 'flag': '🇧🇪'},
    {'code': '+351', 'name': 'Portugal', 'flag': '🇵🇹'},
    {'code': '+30', 'name': 'Greece', 'flag': '🇬🇷'},
    {'code': '+90', 'name': 'Turkey', 'flag': '🇹🇷'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+60', 'name': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+62', 'name': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+66', 'name': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+63', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+84', 'name': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+92', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'name': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+94', 'name': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+977', 'name': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+27', 'name': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'name': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+254', 'name': 'Kenya', 'flag': '🇰🇪'},
    {'code': '+20', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+972', 'name': 'Israel', 'flag': '🇮🇱'},
    {'code': '+64', 'name': 'New Zealand', 'flag': '🇳🇿'},
    {'code': '+54', 'name': 'Argentina', 'flag': '🇦🇷'},
    {'code': '+56', 'name': 'Chile', 'flag': '🇨🇱'},
    {'code': '+57', 'name': 'Colombia', 'flag': '🇨🇴'},
    {'code': '+51', 'name': 'Peru', 'flag': '🇵🇪'},
    {'code': '+58', 'name': 'Venezuela', 'flag': '🇻🇪'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.initialCode;
  }

  String _getFlagForCode(String code) {
    final country = countryCodes.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'flag': '🌍'},
    );
    return country['flag'] ?? '🌍';
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCodes = countryCodes.where((country) {
              final name = country['name']!.toLowerCase();
              final code = country['code']!.toLowerCase();
              return name.contains(searchQuery.toLowerCase()) ||
                  code.contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Select Country Code',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search country...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredCodes.length,
                          itemBuilder: (context, index) {
                            final country = filteredCodes[index];
                            final isSelected = country['code'] == _selectedCode;
                            return ListTile(
                              leading: Text(
                                country['flag']!,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(
                                country['name']!,
                                style: GoogleFonts.poppins(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              trailing: Text(
                                country['code']!,
                                style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? const Color(0xFFB64166)
                                      : Colors.grey.shade600,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              selected: isSelected,
                              selectedTileColor:
                                  const Color(0xFFB64166).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedCode = country['code']!;
                                });
                                widget.onCodeChanged(country['code']!);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Country code dropdown button
        GestureDetector(
          onTap: _showCountryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showFlag)
                  Text(
                    _getFlagForCode(_selectedCode),
                    style: const TextStyle(fontSize: 18),
                  ),
                if (widget.showFlag) const SizedBox(width: 4),
                Text(
                  _selectedCode,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Phone number input
        Expanded(
          child: TextFormField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade600,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Colors.purple.shade600,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Colors.red.shade300,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: Colors.red.shade300,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: widget.validator,
          ),
        ),
      ],
    );
  }

  String getFullPhoneNumber() {
    return '$_selectedCode ${widget.phoneController.text.trim()}';
  }
}

// Simplified version for dialogs
class PhoneInputWithCountryCode extends StatefulWidget {
  final TextEditingController phoneController;
  final Function(String) onFullNumberChanged;

  const PhoneInputWithCountryCode({
    Key? key,
    required this.phoneController,
    required this.onFullNumberChanged,
  }) : super(key: key);

  // Public access to country codes list
  static const List<Map<String, String>> countryCodes = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA/Canada', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+82', 'name': 'South Korea', 'flag': '🇰🇷'},
    {'code': '+7', 'name': 'Russia', 'flag': '🇷🇺'},
    {'code': '+55', 'name': 'Brazil', 'flag': '🇧🇷'},
    {'code': '+52', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': '+34', 'name': 'Spain', 'flag': '🇪🇸'},
    {'code': '+39', 'name': 'Italy', 'flag': '🇮🇹'},
    {'code': '+31', 'name': 'Netherlands', 'flag': '🇳🇱'},
    {'code': '+41', 'name': 'Switzerland', 'flag': '🇨🇭'},
    {'code': '+46', 'name': 'Sweden', 'flag': '🇸🇪'},
    {'code': '+47', 'name': 'Norway', 'flag': '🇳🇴'},
    {'code': '+45', 'name': 'Denmark', 'flag': '🇩🇰'},
    {'code': '+358', 'name': 'Finland', 'flag': '🇫🇮'},
    {'code': '+48', 'name': 'Poland', 'flag': '🇵🇱'},
    {'code': '+43', 'name': 'Austria', 'flag': '🇦🇹'},
    {'code': '+32', 'name': 'Belgium', 'flag': '🇧🇪'},
    {'code': '+351', 'name': 'Portugal', 'flag': '🇵🇹'},
    {'code': '+30', 'name': 'Greece', 'flag': '🇬🇷'},
    {'code': '+90', 'name': 'Turkey', 'flag': '🇹🇷'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+966', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+60', 'name': 'Malaysia', 'flag': '🇲🇾'},
    {'code': '+62', 'name': 'Indonesia', 'flag': '🇮🇩'},
    {'code': '+66', 'name': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+63', 'name': 'Philippines', 'flag': '🇵🇭'},
    {'code': '+84', 'name': 'Vietnam', 'flag': '🇻🇳'},
    {'code': '+92', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': '+880', 'name': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': '+94', 'name': 'Sri Lanka', 'flag': '🇱🇰'},
    {'code': '+977', 'name': 'Nepal', 'flag': '🇳🇵'},
    {'code': '+27', 'name': 'South Africa', 'flag': '🇿🇦'},
    {'code': '+234', 'name': 'Nigeria', 'flag': '🇳🇬'},
    {'code': '+254', 'name': 'Kenya', 'flag': '🇰🇪'},
    {'code': '+20', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+972', 'name': 'Israel', 'flag': '🇮🇱'},
    {'code': '+64', 'name': 'New Zealand', 'flag': '🇳🇿'},
    {'code': '+54', 'name': 'Argentina', 'flag': '🇦🇷'},
    {'code': '+56', 'name': 'Chile', 'flag': '🇨🇱'},
    {'code': '+57', 'name': 'Colombia', 'flag': '🇨🇴'},
    {'code': '+51', 'name': 'Peru', 'flag': '🇵🇪'},
    {'code': '+58', 'name': 'Venezuela', 'flag': '🇻🇪'},
  ];

  @override
  State<PhoneInputWithCountryCode> createState() =>
      PhoneInputWithCountryCodeState();
}

class PhoneInputWithCountryCodeState extends State<PhoneInputWithCountryCode> {
  String _selectedCode = '+91';

  String get fullPhoneNumber =>
      '$_selectedCode ${widget.phoneController.text.trim()}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCode,
              isDense: true,
              items: PhoneInputWithCountryCode.countryCodes.map((country) {
                return DropdownMenuItem<String>(
                  value: country['code'],
                  child: Text(
                    '${country['flag']} ${country['code']}',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCode = value;
                  });
                  widget.onFullNumberChanged(
                      '$_selectedCode ${widget.phoneController.text}');
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Phone Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              widget.onFullNumberChanged('$_selectedCode $value');
            },
          ),
        ),
      ],
    );
  }
}

