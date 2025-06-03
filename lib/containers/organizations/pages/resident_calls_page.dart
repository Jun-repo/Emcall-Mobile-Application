import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ResidentCallsPage extends StatefulWidget {
  final String userType;

  const ResidentCallsPage({super.key, required this.userType});

  @override
  ResidentCallsPageState createState() => ResidentCallsPageState();
}

class ResidentCallsPageState extends State<ResidentCallsPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  FocusNode _focusNode = FocusNode(); // Added FocusNode
  List<Map<String, dynamic>> residentCalls = [];
  int _currentPage = 1;
  int _rowsPerPage = 20; // Default to 20 per page
  bool _isLoading = false;
  int _totalRows = 0;
  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    _fetchResidentCalls();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
      _fetchResidentCalls();
    });

    // Check for focus request from navigation arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ModalRoute.of(context)?.settings.arguments != null &&
          (ModalRoute.of(context)?.settings.arguments as Map)['focusSearch'] ==
              true) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose(); // Dispose of FocusNode
    super.dispose();
  }

  Future<void> _fetchResidentCalls() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    DateTime startDate;

    if (_selectedPeriod == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_selectedPeriod == 'This Week') {
      startDate = now.subtract(Duration(days: now.weekday - 1));
    } else {
      startDate = DateTime(now.year, now.month, 1);
    }

    try {
      final response = await Supabase.instance.client
          .from('service_calls')
          .select(
              '*, residents!inner(first_name, last_name, phone, profile_image, personal_email)')
          .eq('service_type', widget.userType)
          .gte('call_time', startDate.toIso8601String())
          .order('call_time', ascending: false);

      final filteredCalls = response.where((call) {
        final resident = call['residents'];
        final fullName =
            '${resident['first_name']} ${resident['last_name']}'.toLowerCase();
        return fullName.contains(_searchQuery);
      }).toList();

      setState(() {
        residentCalls = filteredCalls;
        _totalRows = filteredCalls.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching calls: $e')),
      );
    }
  }

  void _setPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      _currentPage = 1;
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

  void _nextPage() {
    if ((_currentPage * _rowsPerPage) < _totalRows) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _setRowsPerPage(int newRowsPerPage) {
    setState(() {
      _rowsPerPage = newRowsPerPage;
      _currentPage = 1; // Reset to first page when rows per page changes
    });
    _fetchResidentCalls();
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  List<int> _getPageNumbers() {
    int totalPages = (_totalRows / _rowsPerPage).ceil();
    int startPage = _currentPage - 2 > 0 ? _currentPage - 2 : 1;
    int endPage = startPage + 4 <= totalPages ? startPage + 4 : totalPages;
    startPage = endPage - 4 >= 1 ? endPage - 4 : 1;
    return List.generate(endPage - startPage + 1, (i) => startPage + i);
  }

  @override
  Widget build(BuildContext context) {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) > residentCalls.length
        ? residentCalls.length
        : startIndex + _rowsPerPage;
    final paginatedCalls = residentCalls.sublist(startIndex, endIndex);

    final currentRangeStart = startIndex + 1;
    final currentRangeEnd = endIndex;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Resident Calls', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search Resident Name...',
                prefixIcon: Icon(Icons.search,
                    color: const Color.fromARGB(255, 135, 135, 135)),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodToggle('Today'),
                _buildPeriodToggle('This Week'),
                _buildPeriodToggle('This Month'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : residentCalls.isEmpty
                    ? Center(child: Text('No calls for this period'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16.0),
                        itemCount: paginatedCalls.length,
                        itemBuilder: (context, index) {
                          final call = paginatedCalls[index];
                          final resident = call['residents'];
                          final fullName =
                              '${resident['first_name']} ${resident['last_name']}';
                          final phoneNumber = resident['phone'] ?? 'N/A';
                          final email = resident['personal_email'] ?? 'N/A';
                          final profileImage = resident['profile_image'];
                          final callTime = DateTime.parse(call['call_time']);
                          final formattedDate =
                              DateFormat('MMM d, yyyy h:mm a').format(callTime);

                          return Slidable(
                            key: ValueKey(call['id']),
                            endActionPane: ActionPane(
                              motion: ScrollMotion(),
                              extentRatio: 1.0,
                              children: [
                                SlidableAction(
                                  onPressed: phoneNumber != 'N/A'
                                      ? (_) => _makePhoneCall(phoneNumber)
                                      : null,
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  icon: Icons.call,
                                  label: 'Call',
                                ),
                                SlidableAction(
                                  onPressed: phoneNumber != 'N/A'
                                      ? (_) => _sendSMS(phoneNumber)
                                      : null,
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  icon: Icons.message,
                                  label: 'SMS',
                                ),
                                SlidableAction(
                                  onPressed: email != 'N/A'
                                      ? (_) => _sendEmail(email)
                                      : null,
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  icon: Icons.email,
                                  label: 'Email',
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              margin: EdgeInsets.symmetric(vertical: 2),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: profileImage != null
                                          ? NetworkImage(profileImage)
                                          : AssetImage(
                                                  'assets/images/profile_placeholder.png')
                                              as ImageProvider,
                                      radius: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$currentRangeStart-$currentRangeEnd of $_totalRows Results',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Row(
                  children: [
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      items: [10, 20, 50].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value Per Page'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) _setRowsPerPage(newValue);
                      },
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                      style: TextStyle(color: Colors.black, fontSize: 14),
                      dropdownColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentPage > 1 ? _previousPage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentPage > 1 ? Colors.black87 : Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Back'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _getPageNumbers().map((int page) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 0),
                      child: ElevatedButton(
                        onPressed: () => _goToPage(page),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage == page
                              ? Colors.redAccent
                              : Colors.white,
                          foregroundColor: _currentPage == page
                              ? Colors.white
                              : Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          elevation: 0,
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          page.toString(),
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                ElevatedButton(
                  onPressed:
                      (endIndex < residentCalls.length) ? _nextPage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (endIndex < residentCalls.length)
                        ? Colors.black87
                        : Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Next'),
                ),
              ],
            ),
          ),
        ],
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
              fontWeight: _selectedPeriod == label
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _selectedPeriod == label ? Colors.black : Colors.grey,
            ),
          ),
          SizedBox(height: 5),
          if (_selectedPeriod == label)
            Container(width: 40, height: 2, color: Colors.redAccent),
        ],
      ),
    );
  }
}
