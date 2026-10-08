import 'dart:async';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera initialization error: $e");
  }
  runApp(const SnapShotProApp());
}

class SnapShotProApp extends StatelessWidget {
  const SnapShotProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapShot Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFFFFFC00),
      ),
      home: const SplashScreen(),
    );
  }
}

// -----------------------------------------------------------
// 1. SPLASH SCREEN (SNAPCHAT PRO LOGO ANIMATION)
// -----------------------------------------------------------
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
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
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
      backgroundColor: const Color(0xFFFFFC00),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 68, color: Colors.black),
                    Positioned(
                      top: 24,
                      right: 24,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(0xFFFFFC00),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'SnapShot Pro',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// 2. CAMERA HOME SCREEN (AR OVERLAYS + 10 LIVE FILTERS)
// -----------------------------------------------------------
class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isFlashOn = false;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _captureKey = GlobalKey();

  // Active Filter state
  Color _filterTint = Colors.transparent;
  BlendMode _blendMode = BlendMode.color;
  String _activeFilterName = "Normal";

  // Active AR Mask: none, dog, cat, crown, bighead, thinhead
  String _activeMask = "none";

  final List<Map<String, dynamic>> _filters = [
    {"name": "Normal", "color": Colors.transparent, "mode": BlendMode.color},
    {"name": "Sepia", "color": const Color(0xFF704214).withOpacity(0.42), "mode": BlendMode.color},
    {"name": "Moody Dark", "color": Colors.black.withOpacity(0.35), "mode": BlendMode.darken},
    {"name": "Warm Sunset", "color": Colors.orangeAccent.withOpacity(0.35), "mode": BlendMode.color},
    {"name": "Cyberpunk Cyan", "color": Colors.cyanAccent.withOpacity(0.30), "mode": BlendMode.color},
    {"name": "Golden Hour", "color": Colors.amber.withOpacity(0.38), "mode": BlendMode.color},
    {"name": "B & W", "color": Colors.grey.withOpacity(0.85), "mode": BlendMode.saturation},
    {"name": "Vintage 1998", "color": Colors.brown.withOpacity(0.30), "mode": BlendMode.overlay},
    {"name": "Emerald Dream", "color": Colors.tealAccent.withOpacity(0.25), "mode": BlendMode.color},
    {"name": "Hot Pink", "color": Colors.pinkAccent.withOpacity(0.30), "mode": BlendMode.color},
  ];

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
      if (mounted) setState(() => _isCameraReady = true);
    }
  }

  void _flipCamera() {
    if (cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
      _initCamera();
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _takeSnapshot() async {
    try {
      RenderRepaintBoundary boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File(
              '${tempDir.path}/snap_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(imageFile: file),
        ),
      );
    } catch (e) {
      debugPrint("Capture error: $e");
    }
  }

  Future<void> _importFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(imageFile: File(image.path)),
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
          // Live Feed Captured Layer
          RepaintBoundary(
            key: _captureKey,
            child: Stack(
              children: [
                if (_isCameraReady && _cameraController != null)
                  Positioned.fill(
                    child: _buildCameraFeedWithDistortion(),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFFC00)),
                  ),

                // AR Live Mask Overlay
                if (_activeMask != "none") Positioned.fill(child: _buildAROverlay()),
              ],
            ),
          ),

          // Top Header Tools
          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFFC00), width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFFFFFC00), size: 24),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _activeFilterName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _isFlashOn ? const Color(0xFFFFFC00) : Colors.white),
                      onPressed: _toggleFlash,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                      onPressed: _flipCamera,
                    ),
                  ],
                )
              ],
            ),
          ),

          // AR Face Mask Selection Bar
          Positioned(
            bottom: 155,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 10),
                  _maskChip("No AR", "none"),
                  _maskChip("🐶 Doggy", "dog"),
                  _maskChip("🐱 Kitty", "cat"),
                  _maskChip("👑 Crown", "crown"),
                  _maskChip("🐡 Fat Face", "bighead"),
                  _maskChip("👽 Slim Face", "thinhead"),
                ],
              ),
            ),
          ),

          // 10 Color Filters Bar
          Positioned(
            bottom: 95,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, idx) {
                  final f = _filters[idx];
                  final isSel = _activeFilterName == f['name'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            isSel ? const Color(0xFFFFFC00) : Colors.black54,
                        side: BorderSide(
                          color: isSel ? const Color(0xFFFFFC00) : Colors.white24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _activeFilterName = f['name'];
                          _filterTint = f['color'];
                          _blendMode = f['mode'];
                        });
                      },
                      child: Text(
                        f['name'],
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Action: Gallery + Capture Trigger
          Positioned(
            bottom: 15,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 32),
                  onPressed: _importFromGallery,
                ),
                GestureDetector(
                  onTap: _takeSnapshot,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFC00),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome,
                      color: Color(0xFFFFFC00), size: 30),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("SnapShot Pro AR Engine Active"),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraFeedWithDistortion() {
    double scaleX = 1.0;
    double scaleY = 1.0;

    if (_activeMask == "bighead") {
      scaleX = 1.25;
      scaleY = 0.85;
    } else if (_activeMask == "thinhead") {
      scaleX = 0.78;
      scaleY = 1.20;
    }

    return Transform.scale(
      scaleX: scaleX,
      scaleY: scaleY,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(_filterTint, _blendMode),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildAROverlay() {
    switch (_activeMask) {
      case "dog":
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.2,
                    child: const Text('🐶', style: TextStyle(fontSize: 70)),
                  ),
                  const SizedBox(width: 80),
                  Transform.rotate(
                    angle: 0.2,
                    child: const Text('🐶', style: TextStyle(fontSize: 70)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('👅', style: TextStyle(fontSize: 45)),
            ],
          ),
        );
      case "cat":
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🐱', style: TextStyle(fontSize: 65)),
                  SizedBox(width: 90),
                  Text('🐱', style: TextStyle(fontSize: 65)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('✨', style: TextStyle(fontSize: 40)),
            ],
          ),
        );
      case "crown":
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👑', style: TextStyle(fontSize: 85)),
              SizedBox(height: 120),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _maskChip(String title, String maskKey) {
    bool isSel = _activeMask == maskKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(title, style: TextStyle(color: isSel ? Colors.black : Colors.white)),
        selected: isSel,
        selectedColor: const Color(0xFFFFFC00),
        backgroundColor: Colors.black87,
        onSelected: (val) {
          setState(() => _activeMask = maskKey);
        },
      ),
    );
  }
}

// -----------------------------------------------------------
// 3. EDIT & SAVE STUDIO (DCIM / DOWNLOADS FOLDER)
// -----------------------------------------------------------
class EditorScreen extends StatefulWidget {
  final File imageFile;

  const EditorScreen({super.key, required this.imageFile});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _studioKey = GlobalKey();
  double _brightness = 0.0;
  double _contrast = 1.0;
  bool _isSaving = false;

  List<double> _calcMatrix() {
    final double b = _brightness * 255;
    final double c = _contrast;
    return <double>[
      c, 0, 0, 0, b,
      0, c, 0, 0, b,
      0, 0, c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _saveToStorage() async {
    setState(() => _isSaving = true);
    try {
      RenderRepaintBoundary boundary =
          _studioKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File(
              '${tempDir.path}/SnapShot_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await file.writeAsBytes(pngBytes);

      // Saves directly to Internal Storage / Gallery
      await Gal.putImage(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Saved to Device Gallery & Downloads successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Edit Snapshot", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFFC00),
                    ),
                  )
                : const Icon(Icons.download_for_offline_rounded,
                    color: Color(0xFFFFFC00), size: 32),
            onPressed: _isSaving ? null : _saveToStorage,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _studioKey,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_calcMatrix()),
                  child: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF141414),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _brightness,
                        min: -0.6,
                        max: 0.6,
                        activeColor: const Color(0xFFFFFC00),
                        onChanged: (v) => setState(() => _brightness = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.contrast, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
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
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// 4. USER PROFILE CREATION & BIO SCREEN
// -----------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String _selectedEmoji = '😎';

  final List<String> _emojis = ['😎', '🎨', '🚀', '📸', '🔥', '👑', '⚡', '😇'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'Bhavin Sir';
      _bioController.text =
          prefs.getString('user_bio') ?? 'Sketch Artist & Tech Creator';
      _selectedEmoji = prefs.getString('user_emoji') ?? '👑';
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    await prefs.setString('user_bio', _bioController.text);
    await prefs.setString('user_emoji', _selectedEmoji);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile details saved successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("SnapShot Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFFFC00),
                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.verified, color: Colors.blueAccent, size: 24),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emoji Mood Selector
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = _emojis[i]),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedEmoji == _emojis[i]
                            ? const Color(0xFFFFFC00)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_emojis[i], style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Display Name",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Status & Bio",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFC00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saveProfile,
                child: const Text("Save Profile",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
