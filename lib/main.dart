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
    debugPrint("$e");
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
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFFFFFC00),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();

    Timer(const Duration(milliseconds: 1500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraHomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFC00),
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 25,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.camera_alt_rounded, size: 64, color: Colors.black),
                Positioned(
                  top: 22,
                  right: 22,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFC00),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  int _camIndex = 0;
  bool _isInit = false;
  bool _isFlash = false;
  bool _isRecording = false;
  final GlobalKey _captureKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  String _currentFilter = "Normal";
  Color _tint = Colors.transparent;
  BlendMode _blend = BlendMode.color;

  String _currentAR = "none";
  late AnimationController _musicAnim;

  final List<Map<String, dynamic>> _filters = [
    {"name": "Normal", "color": Colors.transparent, "mode": BlendMode.color},
    {"name": "Sepia", "color": const Color(0xFF704214).withOpacity(0.4), "mode": BlendMode.color},
    {"name": "Moody", "color": Colors.black.withOpacity(0.4), "mode": BlendMode.darken},
    {"name": "Sunset", "color": Colors.deepOrangeAccent.withOpacity(0.35), "mode": BlendMode.color},
    {"name": "Cyber", "color": Colors.cyanAccent.withOpacity(0.35), "mode": BlendMode.color},
    {"name": "Golden", "color": Colors.amber.withOpacity(0.4), "mode": BlendMode.color},
    {"name": "B & W", "color": Colors.grey.withOpacity(0.9), "mode": BlendMode.saturation},
    {"name": "Vintage", "color": Colors.brown.withOpacity(0.3), "mode": BlendMode.overlay},
    {"name": "Emerald", "color": Colors.tealAccent.withOpacity(0.25), "mode": BlendMode.color},
    {"name": "Neon Pink", "color": Colors.pinkAccent.withOpacity(0.3), "mode": BlendMode.color},
  ];

  final List<Map<String, String>> _arList = [
    {"id": "none", "label": "Clear", "icon": "🚫"},
    {"id": "dog", "label": "Puppy", "icon": "🐶"},
    {"id": "cat", "label": "Kitty", "icon": "🐱"},
    {"id": "crown", "label": "Royal", "icon": "👑"},
    {"id": "glasses", "label": "Neon", "icon": "🕶️"},
    {"id": "bunny", "label": "Bunny", "icon": "🐰"},
    {"id": "angel", "label": "Halo", "icon": "😇"},
    {"id": "devil", "label": "Horns", "icon": "😈"},
    {"id": "butterfly", "label": "Flora", "icon": "🦋"},
    {"id": "music_beats", "label": "Music EDM", "icon": "🎵"},
    {"id": "music_wave", "label": "Lo-Fi", "icon": "🎧"},
    {"id": "warp_fat", "label": "Fat Face", "icon": "🐡"},
    {"id": "warp_thin", "label": "Slim Face", "icon": "👽"},
  ];

  @override
  void initState() {
    super.initState();
    _initCam();
    _musicAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  Future<void> _initCam() async {
    await [Permission.camera, Permission.microphone].request();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[_camIndex],
        ResolutionPreset.max,
        enableAudio: true,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInit = true);
    }
  }

  void _flipCam() {
    if (cameras.length > 1) {
      _camIndex = (_camIndex == 0) ? 1 : 0;
      _initCam();
    }
  }

  void _toggleTorch() async {
    if (_controller == null) return;
    setState(() => _isFlash = !_isFlash);
    await _controller!.setFlashMode(_isFlash ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _recordVideoToggle() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) {
      XFile video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      await Gal.putVideo(video.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video recorded & saved to Gallery!"), backgroundColor: Colors.green),
      );
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  Future<void> _captureSnap() async {
    try {
      RenderRepaintBoundary b =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image img = await b.toImage(pixelRatio: 2.8);
      var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      var bytes = byteData!.buffer.asUint8List();

      final tmp = Directory.systemTemp;
      final file = await File('${tmp.path}/snap_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showDecisionSheet(file);
    } catch (e) {
      debugPrint("$e");
    }
  }

  void _showDecisionSheet(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 20),
              const Text("Snap Captured!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFFFFC00), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.download_rounded, color: Color(0xFFFFFC00)),
                      label: const Text("Save to Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Gal.putImage(file.path);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Directly saved to Gallery!"), backgroundColor: Colors.green),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFFFC00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.tune_rounded, color: Colors.black),
                      label: const Text("Edit Snapshot", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FullEditorStudio(imageFile: file)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickGallery() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FullEditorStudio(imageFile: File(img.path))),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _musicAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: (_isInit && _controller != null)
                  ? ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: size.width,
                            height: size.width * _controller!.value.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildPreview(),
                                if (_currentAR != "none") _buildAR(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator(color: Color(0xFFFFFC00))),
            ),
          ),

          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileView()));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFFC00), width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFFFFFC00), size: 22),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    _isRecording ? "🔴 RECORDING" : _currentFilter,
                    style: TextStyle(
                      color: _isRecording ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isFlash ? Icons.flash_on : Icons.flash_off,
                          color: _isFlash ? const Color(0xFFFFFC00) : Colors.white),
                      onPressed: _toggleTorch,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                      onPressed: _flipCam,
                    ),
                  ],
                )
              ],
            ),
          ),

          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _arList.length,
                itemBuilder: (ctx, i) {
                  final item = _arList[i];
                  final isSel = _currentAR == item['id'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text("${item['icon']} ${item['label']}"),
                      selected: isSel,
                      selectedColor: const Color(0xFFFFFC00),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: Colors.black87,
                      onSelected: (val) {
                        setState(() => _currentAR = item['id']!);
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            bottom: 105,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (ctx, i) {
                  final f = _filters[i];
                  final isSel = _currentFilter == f['name'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSel ? const Color(0xFFFFFC00) : Colors.black54,
                        side: BorderSide(color: isSel ? const Color(0xFFFFFC00) : Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentFilter = f['name'];
                          _tint = f['color'];
                          _blend = f['mode'];
                        });
                      },
                      child: Text(
                        f['name'],
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
                  onPressed: _pickGallery,
                ),
                GestureDetector(
                  onTap: _captureSnap,
                  onLongPress: _recordVideoToggle,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording ? Colors.redAccent : Colors.white,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isRecording ? 35 : 60,
                        height: _isRecording ? 35 : 60,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : const Color(0xFFFFFC00),
                          borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop_circle : Icons.videocam_rounded,
                    color: _isRecording ? Colors.redAccent : const Color(0xFFFFFC00),
                    size: 32,
                  ),
                  onPressed: _recordVideoToggle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    double sx = 1.0;
    double sy = 1.0;
    if (_currentAR == "warp_fat") {
      sx = 1.35;
      sy = 0.82;
    } else if (_currentAR == "warp_thin") {
      sx = 0.72;
      sy = 1.25;
    }

    return Transform.scale(
      scaleX: sx,
      scaleY: sy,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(_tint, _blend),
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildAR() {
    switch (_currentAR) {
      case "dog":
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(angle: -0.3, child: const Text('🐶', style: TextStyle(fontSize: 75))),
                  const SizedBox(width: 85),
                  Transform.rotate(angle: 0.3, child: const Text('🐶', style: TextStyle(fontSize: 75))),
                ],
              ),
              const SizedBox(height: 25),
              const Text('👅', style: TextStyle(fontSize: 48)),
            ],
          ),
        );
      case "cat":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🐱', style: TextStyle(fontSize: 65)),
                  SizedBox(width: 95),
                  Text('🐱', style: TextStyle(fontSize: 65)),
                ],
              ),
              SizedBox(height: 15),
              Text('🐾', style: TextStyle(fontSize: 35)),
            ],
          ),
        );
      case "crown":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👑', style: TextStyle(fontSize: 90)),
              SizedBox(height: 140),
            ],
          ),
        );
      case "glasses":
        return const Center(
          child: Text('🕶️', style: TextStyle(fontSize: 100)),
        );
      case "bunny":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🐰', style: TextStyle(fontSize: 90)),
              SizedBox(height: 120),
            ],
          ),
        );
      case "angel":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😇', style: TextStyle(fontSize: 85)),
              SizedBox(height: 120),
            ],
          ),
        );
      case "devil":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😈', style: TextStyle(fontSize: 90)),
              SizedBox(height: 130),
            ],
          ),
        );
      case "butterfly":
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🦋 ✨ 🦋', style: TextStyle(fontSize: 50)),
              SizedBox(height: 140),
            ],
          ),
        );
      case "music_beats":
        return AnimatedBuilder(
          animation: _musicAnim,
          builder: (ctx, ch) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 30.0 + (i * 12.0 * _musicAnim.value),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFC00),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text("🎵 EDM BASS BOOST 🔊", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        );
      case "music_wave":
        return AnimatedBuilder(
          animation: _musicAnim,
          builder: (ctx, ch) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded, color: Color(0xFFFFFC00)),
                    const SizedBox(width: 8),
                    Text("Lo-Fi Chill Hop Vibes ~ ${(_musicAnim.value * 100).toInt()} BPM",
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class FullEditorStudio extends StatefulWidget {
  final File imageFile;

  const FullEditorStudio({super.key, required this.imageFile});

  @override
  State<FullEditorStudio> createState() => _FullEditorStudioState();
}

class _FullEditorStudioState extends State<FullEditorStudio> {
  final GlobalKey _studioKey = GlobalKey();

  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _aperture = 0.0;
  double _rotation = 0.0;

  String _activeTool = "Adjust";
  String _activeFilter = "Original";
  Color _tint = Colors.transparent;
  BlendMode _blend = BlendMode.color;

  final List<Offset?> _points = [];
  Color _brushColor = const Color(0xFFFFFC00);
  double _borderWidth = 0.0;
  Color _borderColor = Colors.white;

  bool _isSaving = false;

  List<double> _buildMatrix() {
    final double b = _brightness * 255;
    final double c = _contrast;
    final double s = _saturation;
    final double inv = 1 - s;
    final double r = 0.213 * inv;
    final double g = 0.715 * inv;
    final double bl = 0.072 * inv;

    return <double>[
      (r + s) * c, g * c, bl * c, 0, b,
      r * c, (g + s) * c, bl * c, 0, b,
      r * c, g * c, (bl + s) * c, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _exportFinal() async {
    setState(() => _isSaving = true);
    try {
      RenderRepaintBoundary b =
          _studioKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image img = await b.toImage(pixelRatio: 3.0);
      var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      var bytes = byteData!.buffer.asUint8List();

      final tmp = Directory.systemTemp;
      final file = await File('${tmp.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(bytes);

      await Gal.putImage(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved to Gallery & Downloads successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Studio Editor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFC00)))
                : const Icon(Icons.check_circle_rounded, color: Color(0xFFFFFC00), size: 28),
            onPressed: _isSaving ? null : _exportFinal,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _studioKey,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor, width: _borderWidth),
                  ),
                  child: Transform.rotate(
                    angle: _rotation,
                    child: GestureDetector(
                      onPanUpdate: (d) {
                        if (_activeTool == "Doodle") {
                          RenderBox r = context.findRenderObject() as RenderBox;
                          setState(() => _points.add(r.globalToLocal(d.globalPosition)));
                        }
                      },
                      onPanEnd: (d) {
                        if (_activeTool == "Doodle") setState(() => _points.add(null));
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ColorFiltered(
                            colorFilter: ColorFilter.matrix(_buildMatrix()),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(_tint, _blend),
                              child: Image.file(widget.imageFile, fit: BoxFit.contain),
                            ),
                          ),
                          if (_aperture > 0)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    radius: 1.0 - (_aperture * 0.4),
                                    colors: [Colors.transparent, Colors.black.withOpacity(_aperture)],
                                  ),
                                ),
                              ),
                            ),
                          CustomPaint(
                            painter: DoodlePainter(points: _points, color: _brushColor),
                            size: Size.infinite,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          _buildControlPanel(),

          Container(
            height: 72,
            color: Colors.black,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _toolTab("Adjust", Icons.tune_rounded),
                _toolTab("Filters", Icons.filter_vintage_rounded),
                _toolTab("Framing", Icons.crop_rotate_rounded),
                _toolTab("Doodle", Icons.edit_rounded),
                _toolTab("Borders", Icons.border_outer_rounded),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _toolTab(String label, IconData icon) {
    bool isSel = _activeTool == label;
    return GestureDetector(
      onTap: () => setState(() => _activeTool = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSel ? const Color(0xFFFFFC00) : Colors.white60, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSel ? const Color(0xFFFFFC00) : Colors.white60,
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    switch (_activeTool) {
      case "Adjust":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF161616),
          child: Column(
            children: [
              _slider("Brightness", Icons.wb_sunny, _brightness, -0.6, 0.6, (v) => setState(() => _brightness = v)),
              _slider("Contrast", Icons.contrast, _contrast, 0.5, 2.0, (v) => setState(() => _contrast = v)),
              _slider("Aperture / Vignette", Icons.camera, _aperture, 0.0, 0.9, (v) => setState(() => _aperture = v)),
              _slider("Saturation", Icons.color_lens, _saturation, 0.0, 2.0, (v) => setState(() => _saturation = v)),
            ],
          ),
        );
      case "Filters":
        return Container(
          height: 60,
          color: const Color(0xFF161616),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterBtn("Original", Colors.transparent, BlendMode.color),
              _filterBtn("Sepia", const Color(0xFF704214).withOpacity(0.4), BlendMode.color),
              _filterBtn("Cinema Blue", Colors.blueAccent.withOpacity(0.3), BlendMode.color),
              _filterBtn("Warm Gold", Colors.amber.withOpacity(0.35), BlendMode.color),
              _filterBtn("Cyberpunk", Colors.cyanAccent.withOpacity(0.3), BlendMode.color),
              _filterBtn("Noir B&W", Colors.black.withOpacity(0.5), BlendMode.saturation),
            ],
          ),
        );
      case "Framing":
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: const Color(0xFF161616),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                icon: const Icon(Icons.rotate_90_degrees_ccw, color: Colors.white),
                label: const Text("Rotate 90°"),
                onPressed: () => setState(() => _rotation += 1.5708),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Reset Frame"),
                onPressed: () => setState(() => _rotation = 0.0),
              ),
            ],
          ),
        );
      case "Doodle":
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: const Color(0xFF161616),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorDot(const Color(0xFFFFFC00)),
              _colorDot(Colors.redAccent),
              _colorDot(Colors.greenAccent),
              _colorDot(Colors.cyanAccent),
              _colorDot(Colors.white),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: () => setState(() => _points.clear()),
              )
            ],
          ),
        );
      case "Borders":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF161616),
          child: Row(
            children: [
              const Text("Border Width:"),
              Expanded(
                child: Slider(
                  value: _borderWidth,
                  min: 0.0,
                  max: 20.0,
                  activeColor: const Color(0xFFFFFC00),
                  onChanged: (v) => setState(() => _borderWidth = v),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _slider(String t, IconData icon, double val, double min, double max, ValueChanged<double> chg) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(t, style: const TextStyle(fontSize: 11))),
        Expanded(
          child: Slider(
            value: val,
            min: min,
            max: max,
            activeColor: const Color(0xFFFFFC00),
            onChanged: chg,
          ),
        ),
      ],
    );
  }

  Widget _filterBtn(String name, Color c, BlendMode m) {
    bool isSel = _activeFilter == name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: ChoiceChip(
        label: Text(name),
        selected: isSel,
        selectedColor: const Color(0xFFFFFC00),
        labelStyle: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11),
        onSelected: (s) {
          setState(() {
            _activeFilter = name;
            _tint = c;
            _blend = m;
          });
        },
      ),
    );
  }

  Widget _colorDot(Color c) {
    return GestureDetector(
      onTap: () => setState(() => _brushColor = c),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: _brushColor == c ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;

  DoodlePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  String _emoji = '👑';
  final List<String> _list = ['👑', '🎨', '🚀', '📸', '🔥', '⚡', '😎', '😇'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _name.text = p.getString('u_name') ?? 'Bhavin Sir';
      _bio.text = p.getString('u_bio') ?? 'Sketch Artist & Tech Creator';
      _emoji = p.getString('u_emoji') ?? '👑';
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('u_name', _name.text);
    await p.setString('u_bio', _bio.text);
    await p.setString('u_emoji', _emoji);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated!"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("SnapShot Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(radius: 45, backgroundColor: const Color(0xFFFFFC00), child: Text(_emoji, style: const TextStyle(fontSize: 42))),
            const SizedBox(height: 15),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _list
                    .map((e) => GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _emoji == e ? const Color(0xFFFFFC00) : Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 18)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _name, decoration: const InputDecoration(labelText: "Name", filled: true, fillColor: Colors.white10)),
            const SizedBox(height: 12),
            TextField(controller: _bio, decoration: const InputDecoration(labelText: "Bio", filled: true, fillColor: Colors.white10)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFFC00), foregroundColor: Colors.black),
                onPressed: _save,
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
