import 'package:flutter/material.dart';

void main() {
  runApp(const PhotoEditorApp());
}

class PhotoEditorApp extends StatelessWidget {
  const PhotoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Photo Editor Studio',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurpleAccent,
      ),
      home: const PhotoEditorScreen(),
    );
  }
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  // ઇફેક્ટ વેલ્યુઝ
  double _brightness = 0.0; // -1.0 થી 1.0
  double _saturation = 1.0; // 0.0 (B&W) થી 2.0
  Color _tintColor = Colors.transparent;
  BlendMode _blendMode = BlendMode.color;
  String _selectedFilter = 'Normal';

  final String _imageUrl =
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&auto=format&fit=crop&q=80';

  void _reset() {
    setState(() {
      _brightness = 0.0;
      _saturation = 1.0;
      _tintColor = Colors.transparent;
      _blendMode = BlendMode.color;
      _selectedFilter = 'Normal';
    });
  }

  // કલર મેટ્રિક્સ ગણતરી (DartPad વેબ માટે સંપૂર્ણ સપોર્ટેડ)
  List<double> _buildColorMatrix() {
    final double b = _brightness * 255;
    final double s = _saturation;

    final double invSat = 1 - s;
    final double r = 0.213 * invSat;
    final double g = 0.715 * invSat;
    final double bl = 0.072 * invSat;

    return <double>[
      r + s, g, bl, 0, b,
      r, g + s, bl, 0, b,
      r, g, bl + s, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  void _applyFilter(String name, Color color, BlendMode mode, double sat) {
    setState(() {
      _selectedFilter = name;
      _tintColor = color;
      _blendMode = mode;
      _saturation = sat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Editor Pro'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amberAccent),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            tooltip: 'Save',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Changes applied successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ફોટો ડિસ્પ્લે એરિયા
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(_tintColor, _blendMode),
                      child: Image.network(
                        _imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.deepPurpleAccent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ફિલ્ટર પ્રીસેટ બટન્સ (લાઇવ ક્લિકેબલ)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterButton('Normal', Colors.transparent, BlendMode.color, 1.0),
                _filterButton('B & W', Colors.transparent, BlendMode.color, 0.0),
                _filterButton('Sepia', const Color(0xFF704214).withOpacity(0.45), BlendMode.color, 1.0),
                _filterButton('Cool Blue', Colors.blue.withOpacity(0.35), BlendMode.color, 1.0),
                _filterButton('Warm Golden', Colors.orange.withOpacity(0.35), BlendMode.color, 1.2),
                _filterButton('Moody Dark', Colors.black.withOpacity(0.35), BlendMode.darken, 0.8),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // સ્લાઇડર કંટ્રોલ્સ પેનલ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSliderRow(
                  label: 'Brightness',
                  icon: Icons.wb_sunny,
                  value: _brightness,
                  min: -0.6,
                  max: 0.6,
                  activeColor: Colors.amberAccent,
                  onChanged: (val) {
                    setState(() {
                      _brightness = val;
                    });
                  },
                ),
                const SizedBox(height: 6),
                _buildSliderRow(
                  label: 'Saturation',
                  icon: Icons.color_lens,
                  value: _saturation,
                  min: 0.0,
                  max: 2.0,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (val) {
                    setState(() {
                      _saturation = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, Color color, BlendMode mode, double sat) {
    final bool isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.deepPurpleAccent : Colors.white10,
          side: BorderSide(
            color: isSelected ? Colors.deepPurpleAccent : Colors.white24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () => _applyFilter(label, color, mode, sat),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: activeColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: activeColor,
            inactiveColor: Colors.white12,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
