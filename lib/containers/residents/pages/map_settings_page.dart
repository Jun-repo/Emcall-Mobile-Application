import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mode_selection_page.dart';
import 'type_selection_page.dart';

class MapSettingsPage extends StatefulWidget {
  const MapSettingsPage({super.key});

  @override
  MapSettingsPageState createState() => MapSettingsPageState();
}

class MapSettingsPageState extends State<MapSettingsPage> {
  String _mapView = 'Auto';
  bool _keepNorthUp = true;
  bool _autoZoom = true;
  String _mode = 'Day';
  String _mapType = 'Default';
  String _distanceUnit = 'KM';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mapView = prefs.getString('map_view') ?? 'Auto';
      _keepNorthUp = prefs.getBool('keep_north_up') ?? true;
      _autoZoom = prefs.getBool('auto_zoom') ?? true;
      _mode = prefs.getString('map_mode') ?? 'Day';
      _mapType = prefs.getString('map_type') ?? 'Default';
      _distanceUnit = prefs.getString('distance_unit') ?? 'KM';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_view', _mapView);
    await prefs.setBool('keep_north_up', _keepNorthUp);
    await prefs.setBool('auto_zoom', _autoZoom);
    await prefs.setString('map_mode', _mode);
    await prefs.setString('map_type', _mapType);
    await prefs.setString('distance_unit', _distanceUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Map Settings',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map View (3D, Auto, 2D)
              const Text(
                'Map View',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: [
                  _mapView == '3D',
                  _mapView == 'Auto',
                  _mapView == '2D',
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) _mapView = '3D';
                    if (index == 1) _mapView = 'Auto';
                    if (index == 2) _mapView = '2D';
                  });
                  _saveSettings();
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.redAccent,
                color: Colors.black54,
                constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                children: const [
                  Text('3D'),
                  Text('Auto'),
                  Text('2D'),
                ],
              ),
              const Divider(),
              // Keep North Up Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Keep North Up',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  Switch(
                    value: _keepNorthUp,
                    activeColor: Colors.redAccent,
                    onChanged: (value) {
                      setState(() {
                        _keepNorthUp = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
              const Divider(),
              // Auto Zoom Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Auto Zoom',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  Switch(
                    value: _autoZoom,
                    activeColor: Colors.redAccent,
                    onChanged: (value) {
                      setState(() {
                        _autoZoom = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
              const Divider(),
              // Mode (Day, Night)
              ListTile(
                title: const Text(
                  'Mode',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                subtitle: Text(
                  _mode,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () async {
                  final selectedMode = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ModeSelectionPage(currentMode: _mode),
                    ),
                  );
                  if (selectedMode != null) {
                    setState(() {
                      _mode = selectedMode;
                    });
                    _saveSettings();
                  }
                },
              ),
              const Divider(),
              // Type (Default, Map Editors)
              ListTile(
                title: const Text(
                  'Type',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                subtitle: Text(
                  _mapType,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.black54),
                onTap: () async {
                  final selectedType = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TypeSelectionPage(currentType: _mapType),
                    ),
                  );
                  if (selectedType != null) {
                    setState(() {
                      _mapType = selectedType;
                    });
                    _saveSettings();
                  }
                },
              ),
              const Divider(),
              // KM/Miles Navigation Units
              const Text(
                'Navigation Units',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'KM',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      value: 'KM',
                      groupValue: _distanceUnit,
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _distanceUnit = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text(
                        'Miles',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      value: 'Miles',
                      groupValue: _distanceUnit,
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _distanceUnit = value!;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
