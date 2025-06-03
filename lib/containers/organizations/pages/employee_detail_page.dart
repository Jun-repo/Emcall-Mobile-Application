import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class EmployeeDetailPage extends StatefulWidget {
  final Map<String, dynamic> worker;

  const EmployeeDetailPage({super.key, required this.worker});

  @override
  _EmployeeDetailPageState createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch SMS')),
      );
    }
  }

  String formatActiveStatus(DateTime statusChecked) {
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

  void _handleMenuSelection(String value) {
    if (value == 'edit') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit action selected')),
        );
      }
    } else if (value == 'delete') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete action selected')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.save),
                title: Text('Save to Default Location'),
                onTap: () async {
                  Navigator.pop(context);
                  final pdf = pw.Document();
                  final String fullName =
                      '${widget.worker['first_name'] ?? ''} ${widget.worker['last_name'] ?? ''}'
                          .trim();
                  final String phoneNumber = widget.worker['phone'] ?? 'N/A';
                  final String email = widget.worker['personal_email'] ?? 'N/A';
                  final String address = widget.worker['address'] ?? 'N/A';
                  final String candidateId =
                      'DG-${widget.worker['id']?.toString().padLeft(4, '0')}-J23';
                  final DateTime? createdAt =
                      widget.worker['created_at'] != null
                          ? DateTime.parse(widget.worker['created_at'])
                          : DateTime(2023, 1, 13);
                  final String dateApplied = DateFormat('MMMM d, yyyy')
                      .format(createdAt ?? DateTime.now());
                  final String appliedDivision = 'N/A';
                  final String headDivision = 'N/A';

                  pdf.addPage(
                    pw.Page(
                      pageFormat: PdfPageFormat.a4,
                      build: (pw.Context context) {
                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Employee Details',
                                style: pw.TextStyle(
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 20),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Name: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(fullName,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Date Applied: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(dateApplied,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Employee ID: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(candidateId,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Applied Division: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(appliedDivision,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Phone Number: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(phoneNumber,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Head Division: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(headDivision,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Email: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(email,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Address: ',
                                    style: pw.TextStyle(
                                        fontSize: 16,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(address,
                                    style: pw.TextStyle(fontSize: 16)),
                              ],
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text('Generated on: ${DateTime.now().toLocal()}',
                                style: pw.TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ),
                  );

                  final output = await getExternalStorageDirectory();
                  final file = File(
                      "${output?.path}/employee_details_${candidateId}.pdf");
                  await file.writeAsBytes(await pdf.save());

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF saved to ${file.path}')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.folder),
                title: Text('Choose Location'),
                onTap: () async {
                  Navigator.pop(context);
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    final pdf = pw.Document();
                    final String fullName =
                        '${widget.worker['first_name'] ?? ''} ${widget.worker['last_name'] ?? ''}'
                            .trim();
                    final String phoneNumber = widget.worker['phone'] ?? 'N/A';
                    final String email =
                        widget.worker['personal_email'] ?? 'N/A';
                    final String address = widget.worker['address'] ?? 'N/A';
                    final String candidateId =
                        'DG-${widget.worker['id']?.toString().padLeft(4, '0')}-J23';
                    final DateTime? createdAt =
                        widget.worker['created_at'] != null
                            ? DateTime.parse(widget.worker['created_at'])
                            : DateTime(2023, 1, 13);
                    final String dateApplied = DateFormat('MMMM d, yyyy')
                        .format(createdAt ?? DateTime.now());
                    final String appliedDivision = 'N/A';
                    final String headDivision = 'N/A';

                    pdf.addPage(
                      pw.Page(
                        pageFormat: PdfPageFormat.a4,
                        build: (pw.Context context) {
                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Employee Details',
                                  style: pw.TextStyle(
                                      fontSize: 24,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 20),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Name: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(fullName,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Date Applied: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(dateApplied,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Employee ID: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(candidateId,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Applied Division: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(appliedDivision,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Phone Number: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(phoneNumber,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Head Division: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(headDivision,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Email: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(email,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Address: ',
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold)),
                                  pw.Text(address,
                                      style: pw.TextStyle(fontSize: 16)),
                                ],
                              ),
                              pw.SizedBox(height: 20),
                              pw.Text(
                                  'Generated on: ${DateTime.now().toLocal()}',
                                  style: pw.TextStyle(fontSize: 12)),
                            ],
                          );
                        },
                      ),
                    );

                    final file = File(
                        "$selectedDirectory/employee_details_${candidateId}.pdf");
                    await file.writeAsBytes(await pdf.save());

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF saved to ${file.path}')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveNotes() async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/notes_${widget.worker['id']}.txt');
    final notes =
        'Title: ${_titleController.text}\nDescription: ${_descriptionController.text}';
    await file.writeAsString(notes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notes saved to cache')),
      );
    }
    _titleController.clear();
    _descriptionController.clear();
  }

  Future<void> _loadNotes() async {
    final cacheDir = await getTemporaryDirectory();
    final file = File('${cacheDir.path}/notes_${widget.worker['id']}.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      final lines = contents.split('\n');
      if (lines.length >= 2) {
        _titleController.text = lines[0].replaceFirst('Title: ', '');
        _descriptionController.text =
            lines[1].replaceFirst('Description: ', '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fullName =
        '${widget.worker['first_name'] ?? ''} ${widget.worker['last_name'] ?? ''}'
            .trim();
    final String phoneNumber = widget.worker['phone'] ?? 'N/A';
    final String email = widget.worker['personal_email'] ?? 'N/A';
    final String profileImage = widget.worker['profile_image'] ??
        'assets/images/profile_placeholder.png';
    final String address = widget.worker['address'] ?? 'N/A';
    final String candidateId =
        'DG-${widget.worker['id']?.toString().padLeft(4, '0')}-J23';
    final DateTime? statusChecked = widget.worker['status_checked'] != null
        ? DateTime.parse(widget.worker['status_checked'])
        : null;
    final String activeStatus =
        statusChecked != null ? formatActiveStatus(statusChecked) : 'Offline';
    final bool isOnline = activeStatus == 'Just Now';
    final DateTime? createdAt = widget.worker['created_at'] != null
        ? DateTime.parse(widget.worker['created_at'])
        : DateTime(2023, 1, 13);
    final String dateApplied =
        DateFormat('MMMM d, yyyy').format(createdAt ?? DateTime.now());
    final String appliedDivision = 'N/A';
    final String headDivision = 'N/A';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 239, 242, 250),
      appBar: AppBar(
        title: Center(
          child: Text(
            'Employee Detail',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w300,
              color: const Color.fromARGB(255, 97, 115, 138),
            ),
          ),
        ),
        leading: Container(
          margin: EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: Colors.black),
              onSelected: _handleMenuSelection,
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.black),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: profileImage.startsWith('http')
                      ? NetworkImage(profileImage)
                      : AssetImage(profileImage) as ImageProvider,
                  radius: 30,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Position: N/A',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: isOnline
                                ? const Color.fromARGB(255, 0, 144, 70)
                                : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 14,
                              color: isOnline
                                  ? const Color.fromARGB(255, 0, 144, 70)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Basic Information'),
              Tab(text: 'Document'),
              Tab(text: 'Notes'),
            ],
            indicatorColor: Colors.redAccent,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', fullName),
                      _buildInfoRow('Date Applied', dateApplied),
                      _buildInfoRow('Employee ID', candidateId),
                      _buildInfoRow('Applied Division', appliedDivision),
                      _buildInfoRow('Phone Number', phoneNumber),
                      _buildInfoRow('Head Division', headDivision),
                      _buildInfoRow('Email', email),
                      _buildInfoRow('Address', address),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Details',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),
                        _buildDocRow('Name', fullName),
                        _buildDocRow('Date Applied', dateApplied),
                        _buildDocRow('Employee ID', candidateId),
                        _buildDocRow('Applied Division', appliedDivision),
                        _buildDocRow('Phone Number', phoneNumber),
                        _buildDocRow('Head Division', headDivision),
                        _buildDocRow('Email', email),
                        _buildDocRow('Address', address),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 5,
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.save),
                            onPressed: _saveNotes,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 5),
          ElevatedButton(
            onPressed: _exportToPDF,
            child: Text(
              'Export',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: phoneNumber != 'N/A'
                        ? () => _sendSMS(phoneNumber)
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.message,
                          size: 16,
                          color: Colors.black,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Send Message',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: phoneNumber != 'N/A'
                        ? () => _makePhoneCall(phoneNumber)
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Make a Call',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
