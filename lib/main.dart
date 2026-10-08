import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapEdit Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFFFFC00),
      ),
      home: const SplashScreen(),
    );
  }
}

// ----------------------------------------------------
// 1. SPLASH SCREEN (SNAPCHAT STYLE ANIMATION - 1.5 SEC)
// ----------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 1500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraHomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFC00), // Iconic Yellow
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                )
              ],
            ),
            child: const Icon(
              Icons.camera_rounded,
              color: Colors.black,
              size: 70,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 2. CAMERA HOME SCREEN (LIVE FILTERS & CAPTURE)
// ----------------------------------------------------
class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  final ImagePicker _picker = ImagePicker();

  Color _filterTint = Colors.transparent;
  BlendMode _blendMode = BlendMode.color;
  String _selectedFilterName = "Normal";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    }
  }

  void _switchCamera() {
    if (cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
      _initCamera();
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(
            imageFile: File(photo.path),
            initialTint: _filterTint,
            initialMode: _blendMode,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Photo capture error: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(
            imageFile: File(image.path),
            initialTint: Colors.transparent,
            initialMode: BlendMode.color,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview with Live Filter
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(_filterTint, _blendMode),
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFFC00)),
            ),

          // Top Bar Actions
          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                  onPressed: _switchCamera,
                ),
                Text(
                  _selectedFilterName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),

          // Bottom Filter Bubbles + Capture Button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      const SizedBox(width: 15),
                      _filterTab("Normal", Colors.transparent, BlendMode.color),
                      _filterTab("Sepia", const Color(0xFF704214).withOpacity(0.4), BlendMode.color),
                      _filterTab("Moody", Colors.black.withOpacity(0.35), BlendMode.darken),
                      _filterTab("Warm", Colors.orange.withOpacity(0.3), BlendMode.color),
                      _filterTab("Cool", Colors.blue.withOpacity(0.3), BlendMode.color),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFC00),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String name, Color color, BlendMode mode) {
    bool isSel = _selectedFilterName == name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSel ? const Color(0xFFFFFC00) : Colors.black45,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () {
          setState(() {
            _selectedFilterName = name;
            _filterTint = color;
            _blendMode = mode;
          });
        },
        child: Text(
          name,
          style: TextStyle(
            color: isSel ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 3. EDITING SCREEN (SAVE TO GALLERY/DOWNLOAD FOLDER)
// ----------------------------------------------------
class EditorScreen extends StatefulWidget {
  final File imageFile;
  final Color initialTint;
  final BlendMode initialMode;

  const EditorScreen({
    super.key,
    required this.imageFile,
    required this.initialTint,
    required this.initialMode,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _globalKey = GlobalKey();

  late Color _filterColor;
  late BlendMode _blendMode;
  double _brightness = 0.0;
  double _contrast = 1.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _filterColor = widget.initialTint;
    _blendMode = widget.initialMode;
  }

  List<double> _buildMatrix() {
    final double b = _brightness * 255;
    final double c = _contrast;
    return <double>[
      c, 0, 0, 0, b,
      0, c, 0, 0, b,
      0, 0, c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _savePhoto() async {
    setState(() => _isSaving = true);
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File('${tempDir.path}/snapedit_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      // Save directly to Device Media / Gallery (Download / DCIM)
      await Gal.putImage(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Success! Photo saved directly to your device storage."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Save failed: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Edit Snap", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFC00)),
                  )
                : const Icon(Icons.download_rounded, color: Color(0xFFFFFC00), size: 30),
            onPressed: _isSaving ? null : _savePhoto,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _globalKey,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_buildMatrix()),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(_filterColor, _blendMode),
                    child: Image.file(widget.imageFile, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6, color: Colors.amber, size: 20),
                    Expanded(
                      child: Slider(
                        value: _brightness,
                        min: -0.5,
                        max: 0.5,
                        activeColor: const Color(0xFFFFFC00),
                        onChanged: (v) => setState(() => _brightness = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.contrast, color: Colors.cyan, size: 20),
                    Expanded(
                      child: Slider(
                        value: _contrast,
                        min: 0.5,
                        max: 2.0,
                        activeColor: const Color(0xFFFFFC00),
                        onChanged: (v) => setState(() => _contrast = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
