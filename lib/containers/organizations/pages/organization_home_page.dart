import 'dart:typed_data';

import 'package:emcall/containers/organizations/filter_bottom_sheet.dart';
import 'package:emcall/containers/organizations/pages/employee_detail_page.dart';
import 'package:emcall/containers/organizations/pages/generate_token_page.dart';
import 'package:emcall/containers/organizations/pages/notification_page.dart';
import 'package:emcall/containers/organizations/pages/resident_calls_page.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'navigation_bar.dart' as custom_nav;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OrganizationHomePage extends StatefulWidget {
  final String orgName;
  final String orgAddress;

  const OrganizationHomePage({
    super.key,
    required this.orgName,
    required this.orgAddress,
  });

  @override
  OrganizationHomePageState createState() => OrganizationHomePageState();
}

class OrganizationHomePageState extends State<OrganizationHomePage> {
  String currentPage = 'Overview';
  String userType = 'rescue';
  int unseenCallsCount = 0;
  String currentSixMonths = '';
  String selectedPeriod = 'Today';
  List<Map<String, dynamic>> residentCalls = [];
  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> analyticsCalls = [];
  List<Map<String, dynamic>> _exportHistory = [];
  Map<String, bool> _expandedSections = {};
  final TextEditingController _searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  List<Map<String, dynamic>> callerLocations = [];
  String _searchQuery = '';
  int _expandedCardIndex = -1;
  bool _isMultiSelectMode = false;
  Set<int> _selectedCallIds = {};
  // Store filter settings
  List<String> _filteredFields = [];
  Map<String, List<String>> _fieldOrder = {
    'identification': [],
    'personalInfo': [],
    'contactInfo': [],
  };
  List<Marker> markers = [];

  int _currentPage = 1; // Current page number
  int _rowsPerPage = 5; // Default rows per page
  List<int> _rowsPerPageOptions = [5, 10, 20];

  @override
  void initState() {
    super.initState();
    _fetchUnseenCallsCount();
    currentSixMonths = getCurrentSixMonths();
    _fetchResidentCalls();
    _fetchWorkers();
    _loadExportHistory();
    _fetchAnalyticsCalls();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getTotalPages() {
    return (analyticsCalls.length / _rowsPerPage).ceil();
  }

  List<Map<String, dynamic>> _getPaginatedCalls() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return analyticsCalls.sublist(startIndex,
        endIndex > analyticsCalls.length ? analyticsCalls.length : endIndex);
  }

  void _nextPage() {
    if (_currentPage < _getTotalPages()) {
      setState(() {
        _currentPage++;
        _expandedCardIndex =
            -1; // Collapse any expanded card when changing pages
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _expandedCardIndex =
            -1; // Collapse any expanded card when changing pages
      });
    }
  }

  void _onRowsPerPageChanged(String? value) {
    setState(() {
      _rowsPerPage = int.parse(value!);
      _currentPage = 1; // Reset to first page when rows per page changes
      _expandedCardIndex = -1; // Collapse any expanded card
    });
  }

  Future<void> _loadExportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('export_history');
    if (historyJson != null) {
      setState(() {
        _exportHistory =
            List<Map<String, dynamic>>.from(json.decode(historyJson));
      });
    }
  }

  Future<void> _saveExportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('export_history', json.encode(_exportHistory));
  }

  Future<void> _fetchUnseenCallsCount() async {
    final response = await Supabase.instance.client
        .from('service_calls')
        .select('id')
        .eq('service_type', userType)
        .eq('is_seen', false)
        .count(CountOption.exact);
    setState(() {
      unseenCallsCount = response.count;
    });
  }

  String getCurrentSixMonths() {
    final now = DateTime.now();
    final startMonth =
        DateFormat('MMMM').format(DateTime(now.year, now.month - 5));
    final endMonth = DateFormat('MMMM').format(now);
    return '$startMonth-$endMonth';
  }

  Future<void> _fetchResidentCalls() async {
    final now = DateTime.now();
    DateTime startDate;

    if (selectedPeriod == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (selectedPeriod == 'This Week') {
      startDate = now.subtract(Duration(days: now.weekday - 1));
    } else {
      startDate = DateTime(now.year, now.month, 1);
    }

    final response = await Supabase.instance.client
        .from('service_calls')
        .select(
            '*, residents!inner(first_name, last_name, phone, profile_image)')
        .eq('service_type', userType)
        .gte('call_time', startDate.toIso8601String());

    setState(() {
      residentCalls = response;
    });
  }

  Future<void> _fetchAnalyticsCalls() async {
    final response =
        await Supabase.instance.client.from('service_calls').select('''
          id, call_time, service_type,
          residents!inner(
            first_name, middle_name, last_name, suffix_name, username, address, birth_date, status, gender, personal_email, phone, profile_image,
            live_locations!left(is_sharing)
          )
          ''').eq('service_type', userType);

    setState(() {
      analyticsCalls = response.map((call) {
        return {
          ...call,
          'custom_id': generateCustomId(call['id'], widget.orgName),
        };
      }).toList();
    });
  }

  String generateCustomId(int id, String orgName) {
    final orgFirstLetter = orgName.isNotEmpty ? orgName[0].toUpperCase() : 'X';
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final randomChar = chars[DateTime.now().millisecond % chars.length];
    return 'EC${orgFirstLetter}00${id}${randomChar}';
  }

  Future<void> _fetchWorkers() async {
    try {
      final response = await Supabase.instance.client
          .from('workers')
          .select(
              'id, first_name, last_name, profile_image, status_checked, phone, personal_email, address, location_id, created_at')
          .eq('organization_type', userType);
      if (response.isNotEmpty) {
        setState(() {
          workers = response;
        });
      }
    } catch (e) {
      print('Error fetching workers: $e');
    }
  }

  String formatActiveStatus(DateTime? statusChecked) {
    if (statusChecked == null) return 'Never Active';
    final now = DateTime.now();
    final difference = now.difference(statusChecked);

    int years = difference.inDays ~/ 365;
    int months = (difference.inDays % 365) ~/ 30;
    int days = (difference.inDays % 30);
    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;
    int seconds = difference.inSeconds % 60;

    List<String> parts = [];
    if (years > 0) parts.add('${years}y${years > 1 ? 's' : ''}');
    if (months > 0) parts.add('${months}m${months > 1 ? 's' : ''}');
    if (days > 0) parts.add('${days}d${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('${hours}h${hours > 1 ? 's' : ''}');
    if (minutes > 0) parts.add('${minutes}min${minutes > 1 ? 's' : ''}');
    if (seconds > 0 && parts.isEmpty)
      parts.add('${seconds}sec${seconds > 1 ? 's' : ''}');

    return parts.isEmpty ? 'Just Now' : parts.join(', ');
  }

  Future<Map<String, dynamic>> getWorkerStats() async {
    final totalResponse = await Supabase.instance.client
        .from('workers')
        .select('id')
        .eq('organization_type', userType)
        .count(CountOption.exact);
    final totalWorkers = totalResponse.count;

    final activeResponse = await Supabase.instance.client
        .from('workers')
        .select('id')
        .eq('organization_type', userType)
        .gte(
            'status_checked',
            DateTime.now()
                .subtract(const Duration(hours: 24))
                .toIso8601String())
        .count(CountOption.exact);
    final activeWorkers = activeResponse.count;

    final percentage = totalWorkers > 0
        ? ((activeWorkers / totalWorkers) * 100).toStringAsFixed(1)
        : '0';

    return {
      'total': totalWorkers,
      'percentage': percentage,
    };
  }

  Future<Map<String, dynamic>> getResidentStats() async {
    final totalResponse = await Supabase.instance.client
        .from('residents')
        .select('id')
        .count(CountOption.exact);
    final totalResidents = totalResponse.count;

    final callingResponse = await Supabase.instance.client
        .from('service_calls')
        .select('resident_id')
        .eq('service_type', userType);

    final residentIds = (callingResponse as List)
        .map((row) => row['resident_id'] as int)
        .toSet();
    final uniqueCallingResidents = residentIds.length;

    final percentage = totalResidents > 0
        ? ((uniqueCallingResidents / totalResidents) * 100).toStringAsFixed(1)
        : '0';

    return {
      'total': totalResidents,
      'percentage': percentage,
    };
  }

  Future<Map<String, dynamic>> getTotalCalls() async {
    final totalResponse = await Supabase.instance.client
        .from('service_calls')
        .select('id')
        .eq('service_type', userType)
        .count(CountOption.exact);
    final totalCalls = totalResponse.count;

    return {
      'total': totalCalls,
    };
  }

  Future<List<ChartData>> getMonthlyCalls() async {
    final data = await Supabase.instance.client.rpc(
        'get_monthly_calls_by_agency',
        params: {'user_type_param': userType});

    if (data is! List) {
      throw Exception('Unexpected response format: $data');
    }

    return data.map((row) {
      final rescueCalls = (row['rescue_calls'] as num).toInt();
      final policeCalls = (row['police_calls'] as num).toInt();
      final firefighterCalls = (row['firefighter_calls'] as num).toInt();
      final disasterResponderCalls =
          (row['disaster_responder_calls'] as num).toInt();

      return ChartData(
        month: row['month'] as String,
        rescue: userType == 'rescue' ? rescueCalls : 0,
        police: userType == 'police' ? policeCalls : 0,
        firefighter: userType == 'firefighter' ? firefighterCalls : 0,
        disasterResponder:
            userType == 'disaster_responders' ? disasterResponderCalls : 0,
      );
    }).toList();
  }

  void _navigateToPage(String page) {
    setState(() {
      currentPage = page;
    });
  }

  void _setPeriod(String period) {
    setState(() {
      selectedPeriod = period;
    });
    _fetchResidentCalls();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch SMS')),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch email')),
      );
    }
  }

  void _toggleCardExpansion(int index) {
    setState(() {
      _expandedCardIndex = (_expandedCardIndex == index) ? -1 : index;
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedCallIds.clear();
      }
    });
  }

  void _toggleSelectCall(int callId) {
    setState(() {
      if (_selectedCallIds.contains(callId)) {
        _selectedCallIds.remove(callId);
      } else {
        _selectedCallIds.add(callId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedCallIds.length == analyticsCalls.length) {
        _selectedCallIds.clear();
      } else {
        _selectedCallIds =
            analyticsCalls.map((call) => call['id'] as int).toSet();
      }
    });
  }

  Future<void> _exportSelectedCalls() async {
    if (_selectedCallIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No calls selected for export')),
      );
      return;
    }

    // Filter selected calls based on _selectedCallIds
    final selectedCalls = analyticsCalls
        .where((call) => _selectedCallIds.contains(call['id']))
        .toList();

    // If no fields are selected in the filter, export all fields
    final fieldsToExport = _filteredFields.isNotEmpty
        ? _filteredFields
        : [
            'id',
            'custom_id',
            'call_time',
            'service_type',
            'first_name',
            'middle_name',
            'last_name',
            'suffix_name',
            'username',
            'address',
            'birth_date',
            'status',
            'gender',
            'personal_email',
            'phone',
            'profile_image',
          ];

    // Combine ordered fields from all sections to maintain order
    final orderedFields = [
      ..._fieldOrder['identification']!,
      ..._fieldOrder['personalInfo']!,
      ..._fieldOrder['contactInfo']!,
    ].where((field) => fieldsToExport.contains(field)).toList();

    // If no ordered fields match the filtered fields, fall back to filtered fields
    final finalFields =
        orderedFields.isNotEmpty ? orderedFields : fieldsToExport;

    // Create Excel file
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // Add headers
    for (int col = 0; col < finalFields.length; col++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
              .value =
          TextCellValue(finalFields[col].replaceAll('_', ' ').toUpperCase());
    }

    // Add data rows
    for (int row = 0; row < selectedCalls.length; row++) {
      final call = selectedCalls[row];
      final resident = call['residents'];
      for (int col = 0; col < finalFields.length; col++) {
        final field = finalFields[col];
        dynamic value;
        if (field == 'id' ||
            field == 'custom_id' ||
            field == 'call_time' ||
            field == 'service_type') {
          value = call[field];
        } else {
          value = resident[field];
        }
        // Format specific fields
        if (field == 'call_time' && value != null) {
          value =
              DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(value));
        } else if (field == 'birth_date' && value != null) {
          value = DateFormat('MMM d, yyyy').format(DateTime.parse(value));
        }
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1))
            .value = TextCellValue(value?.toString() ?? 'N/A');
      }
    }

    // Auto-fit columns
    for (int col = 0; col < finalFields.length; col++) {
      sheet.getColumnAutoFit(col);
    }

    // Encode the Excel file to bytes and convert to Uint8List
    final excelBytesList = excel.encode();
    if (excelBytesList == null || excelBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to encode Excel file: Empty or null bytes')),
      );
      print('Debug: Excel encode returned null or empty list');
      return;
    }
    final Uint8List excelBytes = Uint8List.fromList(excelBytesList);
    print('Debug: Excel bytes length: ${excelBytes.length}');

    // Generate a default file name
    final defaultFileName =
        'exported_calls_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    try {
      // Handle platform-specific file saving
      if (Platform.isAndroid || Platform.isIOS) {
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          fileName: defaultFileName,
          bytes: excelBytes,
          allowedExtensions: ['xlsx'],
          type: FileType.custom,
        );

        if (outputPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $outputPath')),
          );
          // Record export history
          setState(() {
            _exportHistory.add({
              'fileName': defaultFileName,
              'path': outputPath,
              'timestamp': DateTime.now().toIso8601String(),
            });
            _saveExportHistory();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled')),
          );
        }
      } else {
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel File',
          fileName: defaultFileName,
          allowedExtensions: ['xlsx'],
          type: FileType.custom,
        );

        if (outputPath != null) {
          if (!outputPath.endsWith('.xlsx')) {
            outputPath = '$outputPath.xlsx';
          }

          final file = File(outputPath);
          await file.writeAsBytes(excelBytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $outputPath')),
          );
          // Record export history
          setState(() {
            _exportHistory.add({
              'fileName': defaultFileName,
              'path': outputPath,
              'timestamp': DateTime.now().toIso8601String(),
            });
            _saveExportHistory();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
      print('Debug: Export error: $e');
    } finally {
      _toggleMultiSelectMode();
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FilterBottomSheet(
        onSave: (filters) {
          setState(() {
            _filteredFields = filters['selectedFields'] as List<String>;
            _fieldOrder = filters['fieldOrder'] as Map<String, List<String>>;
            print('Applied filters: $filters');
          });
        },
      ),
    );
  }

  void _hideCheckboxes() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedCallIds.clear();
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupExportHistoryByRelativeDate() {
    final now = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> groupedExports = {
      'Today': [],
      'A week ago': [],
      'A month ago': [],
      'A year ago': [],
    };

    for (var export in _exportHistory) {
      final timestamp = DateTime.parse(export['timestamp']);
      final difference = now.difference(timestamp);

      String relativeDate;
      if (difference.inDays == 0) {
        relativeDate = 'Today';
      } else if (difference.inDays <= 7) {
        relativeDate = 'A week ago';
      } else if (difference.inDays <= 30) {
        relativeDate = 'A month ago';
      } else if (difference.inDays <= 365) {
        relativeDate = 'A year ago';
      } else {
        relativeDate = 'A year ago'; // Anything older than a year
      }

      groupedExports[relativeDate]!.add(export);
    }

    // Sort each group by timestamp (newest first)
    groupedExports.forEach((key, exports) {
      exports.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));
    });

    // Initialize expanded state for each section (default to expanded)
    groupedExports.forEach((relativeDate, _) {
      _expandedSections.putIfAbsent(relativeDate, () => true);
    });

    // Remove empty groups
    return Map.from(groupedExports)..removeWhere((key, value) => value.isEmpty);
  }

  Future<void> fetchCallerLocations() async {
    if (startDate == null || endDate == null) return;

    try {
      final startDateUtc = startDate!.toUtc();
      final endDateUtc = endDate!.toUtc();

      final response = await Supabase.instance.client
          .from('service_calls')
          .select('''
          residents!inner(
            live_locations!inner(latitude, longitude)
          ),
          call_time,
          service_type
        ''')
          .eq('service_type', userType)
          .gte('call_time', startDateUtc.toIso8601String())
          .lte('call_time', endDateUtc.toIso8601String());

      setState(() {
        callerLocations = List<Map<String, dynamic>>.from(response);
        markers = callerLocations
            .map((caller) {
              final resident = caller['residents'] as Map<String, dynamic>?;
              final liveLocation =
                  resident?['live_locations'] as Map<String, dynamic>?;
              final latitude = liveLocation?['latitude'] as double?;
              final longitude = liveLocation?['longitude'] as double?;
              if (latitude != null && longitude != null) {
                return Marker(
                  point: LatLng(latitude, longitude),
                  child: Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                );
              }
              return null;
            })
            .where((marker) => marker != null)
            .toList()
            .cast<Marker>();
      });
    } catch (e) {
      print('Error fetching caller locations: $e');
      setState(() {
        callerLocations = [];
        markers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate 0.5% margin based on screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final marginHorizontal = screenWidth * 0.005; // 0.5% of width
    final marginVertical = screenHeight * 0.005; // 0.5% of height

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 239, 242, 250),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/${userType}.png'),
              radius: 20,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome!',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                Text(widget.orgName,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ResidentCallsPage(userType: userType),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    return SlideTransition(
                        position: animation.drive(tween), child: child);
                  },
                  settings: RouteSettings(arguments: {'focusSearch': true}),
                ),
              );
            },
          ),
          badges.Badge(
            position: badges.BadgePosition.topEnd(top: 1, end: 4),
            badgeContent: Text(unseenCallsCount.toString(),
                style: TextStyle(color: Colors.white)),
            child: IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        NotificationPage(userType: userType),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));
                      return SlideTransition(
                          position: animation.drive(tween), child: child);
                    },
                  ),
                ).then((_) => _fetchUnseenCallsCount());
              },
            ),
          ),
        ],
      ),
      body: currentPage == 'GeoTracker'
          ? Container(
              margin: EdgeInsets.symmetric(
                horizontal: marginHorizontal,
                vertical: marginVertical,
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter:
                      LatLng(9.285059, 118.075707), // Maasin, Quezon, Palawan
                  initialZoom: 10.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.emcall.app',
                  ),
                  MarkerLayer(
                    markers: markers,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentPage == 'Overview') ...[
                      SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FutureBuilder<Map<String, dynamic>>(
                              future: getWorkerStats(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildStatCard(
                                      'Total Employees', 0, 'Loading...',
                                      iconPath:
                                          'assets/icons/employee_icon.png');
                                }
                                if (snapshot.hasError) {
                                  return _buildStatCard(
                                      'Total Employees', 0, 'Error',
                                      iconPath:
                                          'assets/icons/employee_icon.png');
                                }
                                final total = snapshot.data!['total'] as int;
                                final percentage =
                                    snapshot.data!['percentage'] as String;
                                final now = DateTime.now();
                                final formattedDate =
                                    DateFormat('MMM d, yyyy h:mm a')
                                            .format(now) +
                                        ' PST';
                                return _buildStatCard(
                                    'Total Employees', total, formattedDate,
                                    percentage: '+$percentage% active',
                                    iconPath: 'assets/icons/employee_icon.png');
                              },
                            ),
                            SizedBox(width: 6),
                            FutureBuilder<Map<String, dynamic>>(
                              future: getResidentStats(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildStatCard(
                                      'Total Residents', 0, 'Loading...',
                                      iconPath:
                                          'assets/icons/resident_icon.png');
                                }
                                if (snapshot.hasError) {
                                  return _buildStatCard(
                                      'Total Residents', 0, 'Error',
                                      iconPath:
                                          'assets/icons/resident_icon.png');
                                }
                                final total = snapshot.data!['total'] as int;
                                final percentage =
                                    snapshot.data!['percentage'] as String;
                                final now = DateTime.now();
                                final formattedDate =
                                    DateFormat('MMM d, yyyy h:mm a')
                                            .format(now) +
                                        ' PST';
                                return _buildStatCard(
                                    'Total Residents', total, formattedDate,
                                    percentage: '+$percentage% caller',
                                    iconPath: 'assets/icons/resident_icon.png');
                              },
                            ),
                            SizedBox(width: 6),
                            FutureBuilder<Map<String, dynamic>>(
                              future: getTotalCalls(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildStatCard(
                                      'Total Calls', 0, 'Loading...',
                                      iconPath: 'assets/icons/call_icon.png');
                                }
                                if (snapshot.hasError) {
                                  return _buildStatCard(
                                      'Total Calls', 0, 'Error',
                                      iconPath: 'assets/icons/call_icon.png');
                                }
                                final total = snapshot.data!['total'] as int;
                                final now = DateTime.now();
                                final formattedDate =
                                    DateFormat('MMM d, yyyy h:mm a')
                                            .format(now) +
                                        ' PST';
                                return _buildStatCard(
                                    'Total Calls', total, formattedDate,
                                    iconPath: 'assets/icons/call_icon.png');
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text('Monthly Call Records',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(currentSixMonths,
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87))),
                                ],
                              ),
                              SizedBox(height: 10),
                              FutureBuilder<List<ChartData>>(
                                future: getMonthlyCalls(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return SizedBox(
                                        height: 200,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()));
                                  }
                                  if (snapshot.hasError) {
                                    return SizedBox(
                                        height: 200,
                                        child: Center(
                                            child: Text(
                                                'Error: ${snapshot.error}')));
                                  }
                                  final callData = snapshot.data ?? [];
                                  if (callData.isEmpty) {
                                    return SizedBox(
                                        height: 200,
                                        child: Center(
                                            child: Text('No data available')));
                                  }
                                  return SizedBox(
                                    height: 200,
                                    child: BarChart(
                                      BarChartData(
                                        alignment:
                                            BarChartAlignment.spaceAround,
                                        maxY: callData
                                                .map((data) => [
                                                      data.rescue,
                                                      data.police,
                                                      data.firefighter,
                                                      data.disasterResponder
                                                    ].reduce((a, b) =>
                                                        a > b ? a : b))
                                                .reduce(
                                                    (a, b) => a > b ? a : b) +
                                            2,
                                        barTouchData:
                                            BarTouchData(enabled: false),
                                        titlesData: FlTitlesData(
                                          show: true,
                                          bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    const style =
                                                        TextStyle(fontSize: 12);
                                                    if (value.toInt() >= 0 &&
                                                        value.toInt() <
                                                            callData.length) {
                                                      return Text(
                                                          callData[
                                                                  value.toInt()]
                                                              .month,
                                                          style: style);
                                                    }
                                                    return Text('');
                                                  })),
                                          leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    return Text(
                                                        value
                                                            .toInt()
                                                            .toString(),
                                                        style: TextStyle(
                                                            fontSize: 12));
                                                  })),
                                          topTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: false)),
                                          rightTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                  showTitles: false)),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        barGroups: callData
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final data = entry.value;
                                          return BarChartGroupData(
                                            x: index,
                                            barRods: [
                                              if (userType == 'rescue')
                                                BarChartRodData(
                                                  toY: data.rescue.toDouble(),
                                                  color: Colors.blue,
                                                  width: 8,
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                  backDrawRodData:
                                                      BackgroundBarChartRodData(
                                                    show: true,
                                                    toY: callData
                                                            .map((data) => data
                                                                .rescue
                                                                .toDouble())
                                                            .reduce((a, b) =>
                                                                a > b ? a : b) +
                                                        2,
                                                    color: Colors.blue
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                              if (userType == 'police')
                                                BarChartRodData(
                                                  toY: data.police.toDouble(),
                                                  color: Colors.red,
                                                  width: 8,
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                  backDrawRodData:
                                                      BackgroundBarChartRodData(
                                                    show: true,
                                                    toY: callData
                                                            .map((data) => data
                                                                .police
                                                                .toDouble())
                                                            .reduce((a, b) =>
                                                                a > b ? a : b) +
                                                        2,
                                                    color: Colors.red
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                              if (userType == 'firefighter')
                                                BarChartRodData(
                                                  toY: data.firefighter
                                                      .toDouble(),
                                                  color: Colors.orange,
                                                  width: 8,
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                  backDrawRodData:
                                                      BackgroundBarChartRodData(
                                                    show: true,
                                                    toY: callData
                                                            .map((data) => data
                                                                .firefighter
                                                                .toDouble())
                                                            .reduce((a, b) =>
                                                                a > b ? a : b) +
                                                        2,
                                                    color: Colors.orange
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                              if (userType ==
                                                  'disaster_responders')
                                                BarChartRodData(
                                                  toY: data.disasterResponder
                                                      .toDouble(),
                                                  color: Colors.green,
                                                  width: 8,
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                  backDrawRodData:
                                                      BackgroundBarChartRodData(
                                                    show: true,
                                                    toY: callData
                                                            .map((data) => data
                                                                .disasterResponder
                                                                .toDouble())
                                                            .reduce((a, b) =>
                                                                a > b ? a : b) +
                                                        2,
                                                    color: Colors.green
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                            ],
                                            barsSpace: 2,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 10),
                              _buildLegend(),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Resident Calls',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              ResidentCallsPage(
                                                  userType: userType),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.easeInOut;
                                            var tween = Tween(
                                                    begin: begin, end: end)
                                                .chain(
                                                    CurveTween(curve: curve));
                                            return SlideTransition(
                                                position:
                                                    animation.drive(tween),
                                                child: child);
                                          },
                                        ),
                                      );
                                    },
                                    child: Text('View All',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildPeriodToggle('Today'),
                                  _buildPeriodToggle('This Week'),
                                  _buildPeriodToggle('This Month'),
                                ],
                              ),
                              SizedBox(height: 10),
                              residentCalls.isEmpty
                                  ? Center(
                                      child: Text('No calls for this period'))
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: residentCalls.length > 3
                                          ? 3
                                          : residentCalls.length,
                                      itemBuilder: (context, index) {
                                        final call = residentCalls[index];
                                        final resident = call['residents'];
                                        final fullName =
                                            '${resident['first_name']} ${resident['last_name']}';
                                        final phoneNumber =
                                            resident['phone'] ?? 'N/A';
                                        final profileImage =
                                            resident['profile_image'];
                                        return Card(
                                          elevation: 0,
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          margin:
                                              EdgeInsets.symmetric(vertical: 5),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: profileImage !=
                                                              null &&
                                                          profileImage
                                                              .isNotEmpty
                                                      ? NetworkImage(
                                                          profileImage)
                                                      : AssetImage(
                                                              'assets/images/profile_placeholder.png')
                                                          as ImageProvider,
                                                  radius: 20,
                                                ),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(fullName,
                                                          style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                      SizedBox(height: 5),
                                                      Text(phoneNumber,
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color:
                                                                  Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.call,
                                                      color: Colors.green),
                                                  onPressed: phoneNumber !=
                                                          'N/A'
                                                      ? () => _makePhoneCall(
                                                          phoneNumber)
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (currentPage == 'Employees') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Employees',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation,
                                                secondaryAnimation) =>
                                            GenerateTokenPage(),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          const begin = Offset(0.0, 1.0);
                                          const end = Offset.zero;
                                          const curve = Curves.easeInOut;
                                          var tween = Tween(
                                                  begin: begin, end: end)
                                              .chain(CurveTween(curve: curve));
                                          return SlideTransition(
                                              position: animation.drive(tween),
                                              child: child);
                                        },
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.add,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search Employee ...',
                                prefixIcon:
                                    Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: Supabase.instance.client
                                  .from('workers')
                                  .select(
                                      'id, first_name, last_name, profile_image, status_checked, phone, personal_email, address, location_id, created_at')
                                  .eq('organization_type', userType),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                      child: Text('Error: ${snapshot.error}'));
                                }
                                final workerList = snapshot.data ?? [];
                                final filteredWorkers =
                                    workerList.where((worker) {
                                  final fullName =
                                      '${worker['first_name']} ${worker['last_name'] ?? ''}'
                                          .toLowerCase();
                                  return fullName.contains(_searchQuery);
                                }).toList();
                                return filteredWorkers.isEmpty
                                    ? Center(
                                        child: Text('No workers available'))
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: filteredWorkers.length,
                                        itemBuilder: (context, index) {
                                          final worker = filteredWorkers[index];
                                          final fullName =
                                              '${worker['first_name']} ${worker['last_name'] ?? ''}';
                                          final profileImage =
                                              worker['profile_image'];
                                          final statusChecked =
                                              worker['status_checked'] != null
                                                  ? DateTime.parse(
                                                      worker['status_checked'])
                                                  : null;
                                          final activeStatus =
                                              formatActiveStatus(statusChecked);
                                          final phoneNumber =
                                              worker['phone'] ?? 'N/A';
                                          final email =
                                              worker['personal_email'] ?? 'N/A';
                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context,
                                                          animation,
                                                          secondaryAnimation) =>
                                                      EmployeeDetailPage(
                                                          worker: worker),
                                                  transitionsBuilder: (context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child) {
                                                    const begin =
                                                        Offset(1.0, 0.0);
                                                    const end = Offset.zero;
                                                    const curve =
                                                        Curves.easeInOut;
                                                    var tween = Tween(
                                                            begin: begin,
                                                            end: end)
                                                        .chain(CurveTween(
                                                            curve: curve));
                                                    return SlideTransition(
                                                        position: animation
                                                            .drive(tween),
                                                        child: child);
                                                  },
                                                ),
                                              );
                                            },
                                            child: Card(
                                              elevation: 0,
                                              color: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 2),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          backgroundImage: profileImage !=
                                                                      null &&
                                                                  profileImage
                                                                      .isNotEmpty
                                                              ? NetworkImage(
                                                                  profileImage)
                                                              : AssetImage(
                                                                      'assets/images/profile_placeholder.png')
                                                                  as ImageProvider,
                                                          radius: 20,
                                                        ),
                                                        SizedBox(width: 10),
                                                        Expanded(
                                                            child: Text(
                                                                fullName,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold))),
                                                        Row(
                                                          children: [
                                                            GestureDetector(
                                                              onTap: phoneNumber !=
                                                                      'N/A'
                                                                  ? () => _makePhoneCall(
                                                                      phoneNumber)
                                                                  : null,
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 16,
                                                                backgroundColor:
                                                                    Colors
                                                                        .black54,
                                                                child:
                                                                    CircleAvatar(
                                                                  radius: 15,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .grey,
                                                                  child: Icon(
                                                                      Icons
                                                                          .phone,
                                                                      size: 20),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            GestureDetector(
                                                              onTap: phoneNumber !=
                                                                      'N/A'
                                                                  ? () => _sendSMS(
                                                                      phoneNumber)
                                                                  : null,
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 16,
                                                                backgroundColor:
                                                                    Colors
                                                                        .black54,
                                                                child:
                                                                    CircleAvatar(
                                                                  radius: 15,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .grey,
                                                                  child: Icon(
                                                                      Icons
                                                                          .message,
                                                                      size: 20),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            GestureDetector(
                                                              onTap: email !=
                                                                      'N/A'
                                                                  ? () =>
                                                                      _sendEmail(
                                                                          email)
                                                                  : null,
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 16,
                                                                backgroundColor:
                                                                    Colors
                                                                        .black54,
                                                                child:
                                                                    CircleAvatar(
                                                                  radius: 15,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .grey,
                                                                  child: Icon(
                                                                      Icons
                                                                          .email,
                                                                      size: 20),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    Divider(
                                                        color: Colors
                                                            .grey.shade300,
                                                        thickness: 1,
                                                        height: 20),
                                                    Text(
                                                        'Active Status: $activeStatus',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (currentPage == 'Analytics') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (_isMultiSelectMode) ...[
                                      Checkbox(
                                        value: _selectedCallIds.length ==
                                            analyticsCalls.length,
                                        onChanged: (value) =>
                                            _toggleSelectAll(),
                                        activeColor: Colors.redAccent,
                                      ),
                                      GestureDetector(
                                        onTap: _hideCheckboxes,
                                        child: Text(
                                            '${_selectedCallIds.length} Selected',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    if (!_isMultiSelectMode)
                                      Text('Analytics',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selectedCallIds.isNotEmpty
                                      ? _exportSelectedCalls
                                      : null,
                                  icon: Image.asset(
                                      'assets/icons/download_icon.png',
                                      width: 24,
                                      height: 24,
                                      color: Colors.white),
                                  label: const Text('Export',
                                      style: TextStyle(fontFamily: 'Gilroy')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      side: const BorderSide(
                                          color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            analyticsCalls.isEmpty
                                ? Center(child: Text('No call data available'))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Call List with Pagination
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: _getPaginatedCalls().length,
                                        itemBuilder: (context, index) {
                                          final paginatedCalls =
                                              _getPaginatedCalls();
                                          final call = paginatedCalls[index];
                                          final originalIndex =
                                              (_currentPage - 1) *
                                                      _rowsPerPage +
                                                  index;
                                          final resident = call['residents'];
                                          final fullName =
                                              '${resident['first_name']} ${resident['last_name'] ?? ''}';
                                          final callTime =
                                              DateTime.parse(call['call_time']);
                                          final formattedDate =
                                              DateFormat('MMM d, yyyy h:mm a')
                                                      .format(callTime) +
                                                  ' PST';
                                          final cardColor =
                                              _expandedCardIndex ==
                                                      originalIndex
                                                  ? Colors.blue[100]
                                                  : Colors.white;
                                          final isSelected = _selectedCallIds
                                              .contains(call['id']);
                                          return GestureDetector(
                                            onLongPress: () {
                                              _toggleMultiSelectMode();
                                              _toggleSelectCall(call['id']);
                                            },
                                            onTap: _isMultiSelectMode
                                                ? () => _toggleSelectCall(
                                                    call['id'])
                                                : () => _toggleCardExpansion(
                                                    originalIndex),
                                            child: AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              margin: EdgeInsets.symmetric(
                                                  vertical: 1, horizontal: 0),
                                              decoration: BoxDecoration(
                                                color: cardColor,
                                                borderRadius: BorderRadius.zero,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.grey
                                                        .withOpacity(0.5),
                                                    spreadRadius: 1,
                                                    blurRadius: 5,
                                                    offset: Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: Stack(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            if (_isMultiSelectMode)
                                                              Checkbox(
                                                                value:
                                                                    isSelected,
                                                                onChanged: (value) =>
                                                                    _toggleSelectCall(
                                                                        call[
                                                                            'id']),
                                                                activeColor: Colors
                                                                    .redAccent,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            4)),
                                                              ),
                                                            CircleAvatar(
                                                              backgroundImage: resident[
                                                                              'profile_image'] !=
                                                                          null &&
                                                                      resident[
                                                                              'profile_image']
                                                                          .isNotEmpty
                                                                  ? NetworkImage(
                                                                      resident[
                                                                          'profile_image'])
                                                                  : AssetImage(
                                                                          'assets/images/profile_placeholder.png')
                                                                      as ImageProvider,
                                                              radius: 20,
                                                              onBackgroundImageError:
                                                                  (exception,
                                                                      stackTrace) {
                                                                print(
                                                                    'Image load error: $exception');
                                                              },
                                                            ),
                                                            SizedBox(width: 10),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(fullName,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold)),
                                                                  Text(
                                                                      formattedDate,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              14,
                                                                          color:
                                                                              Colors.grey)),
                                                                ],
                                                              ),
                                                            ),
                                                            Icon(
                                                                Icons
                                                                    .arrow_downward_rounded,
                                                                size: 14,
                                                                color: Colors
                                                                    .black),
                                                          ],
                                                        ),
                                                        if (_expandedCardIndex ==
                                                            originalIndex) ...[
                                                          SizedBox(height: 10),
                                                          Divider(
                                                              color: Colors.grey
                                                                  .shade300,
                                                              thickness: 1),
                                                          Column(
                                                            children: [
                                                              _buildDetailRow(
                                                                  'First Name:',
                                                                  resident[
                                                                          'first_name'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Middle Name:',
                                                                  resident[
                                                                          'middle_name'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Last Name:',
                                                                  resident[
                                                                          'last_name'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Suffix:',
                                                                  resident[
                                                                          'suffix_name'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Username:',
                                                                  resident[
                                                                          'username'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Address:',
                                                                  resident[
                                                                          'address'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Birth Date:',
                                                                  resident['birth_date'] !=
                                                                          null
                                                                      ? DateFormat(
                                                                              'MMM d, yyyy')
                                                                          .format(
                                                                              DateTime.parse(resident['birth_date']))
                                                                      : 'N/A'),
                                                              _buildDetailRow(
                                                                  'Status:',
                                                                  resident[
                                                                          'status'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Gender:',
                                                                  resident[
                                                                          'gender'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Email:',
                                                                  resident[
                                                                          'personal_email'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Phone:',
                                                                  resident[
                                                                          'phone'] ??
                                                                      'N/A'),
                                                              _buildDetailRow(
                                                                  'Call ID:',
                                                                  call[
                                                                      'custom_id']),
                                                              _buildDetailRow(
                                                                  'Service Type:',
                                                                  call[
                                                                      'service_type']),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Pagination Controls
                                      SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Row Count Display
                                          Text(
                                            '${((_currentPage - 1) * _rowsPerPage + 1)}-${_currentPage * _rowsPerPage > analyticsCalls.length ? analyticsCalls.length : _currentPage * _rowsPerPage} of ${analyticsCalls.length}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                          // Pagination and Rows Per Page Dropdown
                                          Row(
                                            children: [
                                              // Rows Per Page Dropdown
                                              DropdownButton<String>(
                                                value: _rowsPerPage.toString(),
                                                items: _rowsPerPageOptions
                                                    .map((rows) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: rows.toString(),
                                                    child: Text('$rows rows'),
                                                  );
                                                }).toList(),
                                                onChanged:
                                                    _onRowsPerPageChanged,
                                                underline: Container(),
                                                icon: Icon(
                                                    Icons.arrow_drop_down,
                                                    color: Colors.grey),
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black),
                                              ),
                                              SizedBox(width: 10),
                                              // Previous Page Button
                                              IconButton(
                                                icon: Icon(Icons.arrow_left),
                                                onPressed: _currentPage > 1
                                                    ? _previousPage
                                                    : null,
                                                color: _currentPage > 1
                                                    ? Colors.redAccent
                                                    : Colors.grey,
                                              ),
                                              // Page Number
                                              Text(
                                                'Page $_currentPage of ${_getTotalPages()}',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                              // Next Page Button
                                              IconButton(
                                                icon: Icon(Icons.arrow_right),
                                                onPressed: _currentPage <
                                                        _getTotalPages()
                                                    ? _nextPage
                                                    : null,
                                                color: _currentPage <
                                                        _getTotalPages()
                                                    ? Colors.redAccent
                                                    : Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      // Existing Sections (Call Distribution, Status Overview, Demographics)
                                      SizedBox(height: 20),
                                      Card(
                                        elevation: 0,
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Call Distribution by Time of Day',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              SizedBox(height: 10),
                                              FutureBuilder<List<CallTimeData>>(
                                                future:
                                                    _getCallDistributionByTime(
                                                        analyticsCalls),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return Center(
                                                        child:
                                                            CircularProgressIndicator());
                                                  }
                                                  if (snapshot.hasError) {
                                                    return Center(
                                                        child: Text(
                                                            'Error: ${snapshot.error}'));
                                                  }
                                                  final timeData =
                                                      snapshot.data ?? [];
                                                  return SizedBox(
                                                    height: 200,
                                                    child: BarChart(
                                                      BarChartData(
                                                        alignment:
                                                            BarChartAlignment
                                                                .spaceAround,
                                                        maxY: timeData
                                                                .map((data) =>
                                                                    data.count)
                                                                .reduce((a,
                                                                        b) =>
                                                                    a > b
                                                                        ? a
                                                                        : b) +
                                                            2,
                                                        barTouchData:
                                                            BarTouchData(
                                                                enabled: false),
                                                        titlesData:
                                                            FlTitlesData(
                                                          show: true,
                                                          bottomTitles: AxisTitles(
                                                              sideTitles: SideTitles(
                                                                  showTitles: true,
                                                                  getTitlesWidget: (value, meta) {
                                                                    const style =
                                                                        TextStyle(
                                                                            fontSize:
                                                                                12);
                                                                    if (value.toInt() >=
                                                                            0 &&
                                                                        value.toInt() <
                                                                            timeData.length) {
                                                                      return Text(
                                                                          timeData[value.toInt()]
                                                                              .timeSlot,
                                                                          style:
                                                                              style);
                                                                    }
                                                                    return Text(
                                                                        '');
                                                                  })),
                                                          leftTitles: AxisTitles(
                                                              sideTitles: SideTitles(
                                                                  showTitles: true,
                                                                  reservedSize: 40,
                                                                  getTitlesWidget: (value, meta) {
                                                                    return Text(
                                                                        value
                                                                            .toInt()
                                                                            .toString(),
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12));
                                                                  })),
                                                          topTitles: AxisTitles(
                                                              sideTitles:
                                                                  SideTitles(
                                                                      showTitles:
                                                                          false)),
                                                          rightTitles: AxisTitles(
                                                              sideTitles:
                                                                  SideTitles(
                                                                      showTitles:
                                                                          false)),
                                                        ),
                                                        borderData:
                                                            FlBorderData(
                                                                show: false),
                                                        barGroups: timeData
                                                            .asMap()
                                                            .entries
                                                            .map((entry) {
                                                          final index =
                                                              entry.key;
                                                          final data =
                                                              entry.value;
                                                          return BarChartGroupData(
                                                            x: index,
                                                            barRods: [
                                                              BarChartRodData(
                                                                toY: data.count
                                                                    .toDouble(),
                                                                color:
                                                                    Colors.blue,
                                                                width: 16,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .zero,
                                                                backDrawRodData:
                                                                    BackgroundBarChartRodData(
                                                                  show: true,
                                                                  toY: timeData
                                                                          .map((data) => data
                                                                              .count
                                                                              .toDouble())
                                                                          .reduce((a, b) => a > b
                                                                              ? a
                                                                              : b) +
                                                                      2,
                                                                  color: Colors
                                                                      .blue
                                                                      .withOpacity(
                                                                          0.3),
                                                                ),
                                                              ),
                                                            ],
                                                            barsSpace: 4,
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Card(
                                        elevation: 0,
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Call Status Overview',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              SizedBox(height: 10),
                                              FutureBuilder<Map<String, int>>(
                                                future: _getCallStatusOverview(
                                                    analyticsCalls),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return Center(
                                                        child:
                                                            CircularProgressIndicator());
                                                  }
                                                  if (snapshot.hasError) {
                                                    return Center(
                                                        child: Text(
                                                            'Error: ${snapshot.error}'));
                                                  }
                                                  final statusData =
                                                      snapshot.data ?? {};
                                                  return Column(
                                                    children: statusData.entries
                                                        .map((entry) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 4.0),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(entry.key,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .black)),
                                                            Text(
                                                                entry.value
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .redAccent)),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      Card(
                                        elevation: 0,
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Caller Demographics',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              SizedBox(height: 10),
                                              FutureBuilder<Map<String, int>>(
                                                future: _getCallerDemographics(
                                                    analyticsCalls),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return Center(
                                                        child:
                                                            CircularProgressIndicator());
                                                  }
                                                  if (snapshot.hasError) {
                                                    return Center(
                                                        child: Text(
                                                            'Error: ${snapshot.error}'));
                                                  }
                                                  final demoData =
                                                      snapshot.data ?? {};
                                                  return SizedBox(
                                                    height: 200,
                                                    child: PieChart(
                                                      PieChartData(
                                                        sections: demoData
                                                            .entries
                                                            .map((entry) {
                                                          return PieChartSectionData(
                                                            value: entry.value
                                                                .toDouble(),
                                                            color:
                                                                _getColorForDemographic(
                                                                    entry.key),
                                                            title:
                                                                '${entry.value}',
                                                            radius: 60,
                                                            titleStyle: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white),
                                                          );
                                                        }).toList(),
                                                        sectionsSpace: 2,
                                                        centerSpaceRadius: 40,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ],
                    if (currentPage == 'Downloads') ...[
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export History',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            SizedBox(height: 10),
                            _exportHistory.isEmpty
                                ? Center(
                                    child: Text('No export history available'))
                                : Builder(builder: (context) {
                                    final groupedExports =
                                        _groupExportHistoryByRelativeDate();
                                    if (groupedExports.isEmpty) {
                                      return Center(
                                          child: Text(
                                              'No export history available'));
                                    }
                                    List<Widget> sections = [];
                                    groupedExports
                                        .forEach((relativeDate, exports) {
                                      final isExpanded =
                                          _expandedSections[relativeDate] ??
                                              true;
                                      sections.add(
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 10.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _expandedSections[
                                                    relativeDate] = !isExpanded;
                                              });
                                            },
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  relativeDate,
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey[700]),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  isExpanded
                                                      ? Icons.arrow_drop_down
                                                      : Icons.arrow_drop_up,
                                                  color: Colors.grey[700],
                                                  size: 20,
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 8.0,
                                                            top: 6.0),
                                                    height: 1.0,
                                                    color: Colors.grey[
                                                        400], // Separator line color
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                      if (isExpanded) {
                                        sections.add(
                                          GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2, // 2 columns
                                              crossAxisSpacing: 10,
                                              mainAxisSpacing: 10,
                                              childAspectRatio:
                                                  0.7, // Adjust for content height
                                            ),
                                            itemCount: exports.length,
                                            itemBuilder: (context, index) {
                                              final export = exports[index];
                                              final timestamp = DateTime.parse(
                                                  export['timestamp']);
                                              final formattedTime = DateFormat(
                                                      'MMM d, yyyy h:mm a')
                                                  .format(timestamp);
                                              return Card(
                                                elevation: 0,
                                                color: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.zero),
                                                child: InkWell(
                                                  onTap: () {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(
                                                                'File: ${export['path']}')));
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Center(
                                                            child: Image.asset(
                                                              'assets/images/sheets.png',
                                                              height: 120,
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder:
                                                                  (context,
                                                                      error,
                                                                      stackTrace) {
                                                                return Icon(
                                                                    Icons
                                                                        .file_present,
                                                                    size: 80,
                                                                    color: Colors
                                                                        .green);
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          export['fileName'],
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Path: ${export['path']}',
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.grey),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          ' $formattedTime PST',
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .redAccent),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }
                                    });
                                    return Column(children: sections);
                                  }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      floatingActionButton: currentPage == 'Analytics'
          ? CircleAvatar(
              radius: 32,
              backgroundColor: Colors.redAccent,
              child: IconButton(
                onPressed: _showFilterDialog,
                icon: Image.asset(
                  'assets/icons/filter_table.png',
                  width: 32,
                  height: 32,
                  color: Colors.white,
                ),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
              ),
            )
          : currentPage == 'GeoTracker' // Adjust condition as per your app
              ? FloatingActionButton(
                  onPressed: () async {
                    // Show the date range picker directly
                    final pickedRange = await showDateRangePicker(
                      context: context,
                      initialDateRange: (startDate != null && endDate != null)
                          ? DateTimeRange(start: startDate!, end: endDate!)
                          : null,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.redAccent,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                            dialogBackgroundColor: Colors.white,
                          ),
                          child: child!,
                        );
                      },
                    );

                    // If a range is selected, update state and fetch data
                    if (pickedRange != null) {
                      setState(() {
                        startDate = pickedRange.start;
                        endDate = pickedRange.end;
                      });
                      await fetchCallerLocations();
                    }
                  },
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.calendar_today, color: Colors.white),
                )
              : null,
      bottomNavigationBar: custom_nav.NavigationBar(
        currentPage: currentPage,
        onNavItemTapped: _navigateToPage,
      ),
    );
  }

  Widget _buildStatCard(String title, int count, String updateDate,
      {String percentage = '', required String iconPath}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Row(
              children: [
                Image.asset(iconPath, width: 24, height: 24),
                SizedBox(width: 12),
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        color: const Color.fromARGB(255, 96, 96, 96))),
              ],
            ),
            SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(count.toString(),
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                if (percentage.isNotEmpty) ...[
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 0,
                      color: const Color.fromARGB(23, 1, 172, 12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Center(
                          child: Text(percentage,
                              style: TextStyle(
                                  color: const Color.fromARGB(255, 0, 173, 55),
                                  fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 2),
            Divider(color: Colors.grey.shade300, thickness: 1),
            SizedBox(height: 2),
            Text('Update: $updateDate',
                style: TextStyle(
                    fontSize: 12,
                    color: const Color.fromARGB(255, 96, 96, 96))),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle(String label) {
    return InkWell(
      onTap: () => _setPeriod(label),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  selectedPeriod == label ? FontWeight.bold : FontWeight.normal,
              color: selectedPeriod == label ? Colors.black : Colors.grey,
            ),
          ),
          SizedBox(height: 5),
          if (selectedPeriod == label)
            Container(width: 40, height: 2, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (userType == 'rescue') _buildLegendItem(Colors.blue, 'Rescue Calls'),
        if (userType == 'police') _buildLegendItem(Colors.red, 'Police Calls'),
        if (userType == 'firefighter')
          _buildLegendItem(Colors.orange, 'Firefighter Calls'),
        if (userType == 'disaster_responders')
          _buildLegendItem(Colors.green, 'Disaster Responder Calls'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class ChartData {
  final String month;
  final int rescue;
  final int police;
  final int firefighter;
  final int disasterResponder;

  ChartData({
    required this.month,
    required this.rescue,
    required this.police,
    required this.firefighter,
    required this.disasterResponder,
  });
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.redAccent),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

// Helper class for Call Distribution data
class CallTimeData {
  final String timeSlot;
  final int count;

  CallTimeData(this.timeSlot, this.count);
}

Future<List<CallTimeData>> _getCallDistributionByTime(
    List<Map<String, dynamic>> analyticsCalls) async {
  final timeSlots = <String, int>{
    'Morning (6-12 AM)': 0,
    'Afternoon (12-6 PM)': 0,
    'Evening (6-10 PM)': 0,
    'Night (10 PM-6 AM)': 0,
  };
  for (var call in analyticsCalls) {
    final callTime = DateTime.parse(call['call_time']);
    final hour = callTime.hour;
    if (hour >= 6 && hour < 12) {
      timeSlots['Morning (6-12 AM)'] =
          (timeSlots['Morning (6-12 AM)'] ?? 0) + 1;
    } else if (hour >= 12 && hour < 18) {
      timeSlots['Afternoon (12-6 PM)'] =
          (timeSlots['Afternoon (12-6 PM)'] ?? 0) + 1;
    } else if (hour >= 18 && hour < 22) {
      timeSlots['Evening (6-10 PM)'] =
          (timeSlots['Evening (6-10 PM)'] ?? 0) + 1;
    } else {
      timeSlots['Night (10 PM-6 AM)'] =
          (timeSlots['Night (10 PM-6 AM)'] ?? 0) + 1;
    }
  }
  return timeSlots.entries.map((e) => CallTimeData(e.key, e.value)).toList();
}

Future<Map<String, int>> _getCallStatusOverview(
    List<Map<String, dynamic>> analyticsCalls) async {
  final statusMap = <String, int>{
    'Resolved': 0,
    'Ongoing': 0,
  };

  for (var call in analyticsCalls) {
    final resident = call['residents'];
    final liveLocation = resident['live_locations'] as Map<String, dynamic>?;
    final isSharing = liveLocation != null
        ? liveLocation['is_sharing'] as bool?
        : false; // Default to false if no live location data

    if (isSharing == true) {
      statusMap['Ongoing'] = (statusMap['Ongoing'] ?? 0) + 1;
    } else {
      statusMap['Resolved'] = (statusMap['Resolved'] ?? 0) + 1;
    }
  }

  return statusMap;
}

// Caller Demographics based on gender
Future<Map<String, int>> _getCallerDemographics(
    List<Map<String, dynamic>> analyticsCalls) async {
  final genderMap = <String, int>{'Male': 0, 'Female': 0, 'Other': 0};
  for (var call in analyticsCalls) {
    final resident = call['residents'];
    final gender = resident['gender'] ?? 'Other';
    genderMap[gender] = (genderMap[gender] ?? 0) + 1;
  }
  return genderMap;
}

Color _getColorForDemographic(String key) {
  switch (key) {
    case 'Male':
      return Colors.blue;
    case 'Female':
      return Colors.pink;
    case 'Other':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}
