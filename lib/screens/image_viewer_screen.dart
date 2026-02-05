import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String? caption;
  final bool preventScreenshots;

  const ImageViewerScreen({
    Key? key,
    required this.imageUrl,
    this.caption,
    this.preventScreenshots = false,
  }) : super(key: key);

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isDownloading = false;
  static const platform = MethodChannel('com.orbitalk.screenshot');

  @override
  void initState() {
    super.initState();
    if (widget.preventScreenshots) {
      _enableScreenshotPrevention();
    }
  }

  @override
  void dispose() {
    if (widget.preventScreenshots) {
      _disableScreenshotPrevention();
    }
    super.dispose();
  }

  Future<void> _enableScreenshotPrevention() async {
    try {
      if (Platform.isAndroid) {
        await platform.invokeMethod('enableScreenshotPrevention');
      } else if (Platform.isIOS) {
        await platform.invokeMethod('enableScreenshotPrevention');
      }
      debugPrint('Screenshot prevention enabled');
    } on PlatformException catch (e) {
      debugPrint('Failed to enable screenshot prevention: ${e.message}');
    }
  }

  Future<void> _disableScreenshotPrevention() async {
    try {
      if (Platform.isAndroid) {
        await platform.invokeMethod('disableScreenshotPrevention');
      } else if (Platform.isIOS) {
        await platform.invokeMethod('disableScreenshotPrevention');
      }
      debugPrint('Screenshot prevention disabled');
    } on PlatformException catch (e) {
      debugPrint('Failed to disable screenshot prevention: ${e.message}');
    }
  }

  Future<void> _downloadAndSaveImage() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission based on Android version
      PermissionStatus status;
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use photos permission
        // For older versions, use storage permission
        final androidVersion = await _getAndroidVersion();
        if (androidVersion >= 33) {
          status = await Permission.photos.request();
        } else {
          status = await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        status = await Permission.photosAddOnly.request();
      } else {
        status = PermissionStatus.granted; // For other platforms
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission is required to save images'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      // Download the image
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      // Get external storage directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        // Create UTELO folder in Pictures directory
        final picturesDir = Directory('${directory!.path.split('Android')[0]}Pictures/UTELO');
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        directory = picturesDir;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(widget.imageUrl);
      final fileName = 'orbi_image_$timestamp$extension';
      final filePath = '${directory.path}/$fileName';

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved to: ${directory.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    // Simple way to get Android version - this might need device_info_plus package for more accuracy
    // For now, we'll assume modern Android and handle permission appropriately
    return 30; // Assume Android 11+ for safer permission handling
  }

  String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1) {
      return path.substring(lastDot);
    }
    return '.jpg'; // Default extension
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Photo',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: widget.preventScreenshots ? [] : [
          IconButton(
            onPressed: _isDownloading ? null : _downloadAndSaveImage,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            tooltip: _isDownloading ? 'Downloading...' : 'Save to gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(widget.imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.error, color: Colors.red, size: 40),
            ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.caption!,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
