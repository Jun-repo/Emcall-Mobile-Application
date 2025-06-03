import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:emcall/auth/forms/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountPage extends StatefulWidget {
  final String fullName;
  final String? profileImageUrl;

  const AccountPage({
    super.key,
    required this.fullName,
    this.profileImageUrl,
  });

  @override
  AccountPageState createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  String? residentAddress;
  String? residentEmail;
  String? residentPhone;
  bool isLoading = true;
  int? residentId;
  String? _currentProfileImageUrl;
  String? _fullName; // State variable to store the dynamic full name

  // Controllers for the edit profile form
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;
  String? _selectedStatus;

  // Track if fields have been edited
  bool _isFirstNameEdited = false;
  bool _isMiddleNameEdited = false;
  bool _isLastNameEdited = false;
  bool _isUsernameEdited = false;
  bool _isAgeEdited = false;
  bool _isAddressEdited = false;
  bool _isDateEdited = false;
  bool _isGenderEdited = false;
  bool _isStatusEdited = false;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentProfileImageUrl = widget.profileImageUrl;
    _fullName = widget.fullName; // Initialize with the passed full name
    fetchResidentIdAndData();
  }

  Future<void> fetchResidentData() async {
    if (residentId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('residents')
          .select(
              'address, personal_email, phone, profile_image, first_name, middle_name, last_name, birth_date, gender, username, status')
          .eq('id', residentId!)
          .single();

      setState(() {
        residentAddress = response['address'] ?? 'Not provided';
        residentEmail = response['personal_email'] ?? 'Not provided';
        residentPhone = response['phone'] ?? 'Not provided';
        _currentProfileImageUrl = response['profile_image'];
        // Construct the full name with first, middle, and last names
        final firstName = response['first_name'] ?? '';
        final middleName = response['middle_name'] ?? '';
        final lastName = response['last_name'] ?? '';
        _fullName = [firstName, middleName, lastName]
            .where((name) => name.isNotEmpty)
            .join(' ');
        // Pre-fill form fields with existing data
        _firstNameController.text = firstName;
        _middleNameController.text = middleName;
        _lastNameController.text = lastName;
        _usernameController.text = response['username'] ?? '';
        _addressController.text = response['address'] ?? '';
        _selectedGender = response['gender'];
        // Validate status to match dropdown options
        final status = response['status'];
        const validStatuses = [
          'Single',
          'Married',
          'Divorced',
          'Widowed',
          'Separated'
        ];
        _selectedStatus = validStatuses.contains(status) ? status : null;
        if (response['birth_date'] != null) {
          _selectedDate = DateTime.parse(response['birth_date']);
          // Calculate age based on birth date
          final now = DateTime.now();
          int age = now.year - _selectedDate!.year;
          if (now.month < _selectedDate!.month ||
              (now.month == _selectedDate!.month &&
                  now.day < _selectedDate!.day)) {
            age--;
          }
          _ageController.text = age.toString();
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        residentAddress = 'Error loading address';
        residentEmail = 'Error loading email';
        residentPhone = 'Error loading phone';
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  Future<void> fetchResidentIdAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedResidentId = prefs.getInt('resident_id');

    if (storedResidentId == null) {
      setState(() {
        isLoading = false;
        residentAddress = 'No resident ID found';
        residentEmail = 'Please log in again';
        residentPhone = 'N/A';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: No resident ID found in session')),
        );
        return;
      }
    }

    setState(() {
      residentId = storedResidentId;
    });

    await fetchResidentData();
  }

  void _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all session data
    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Signing out...')),
      );

      Navigator.pushReplacement(
        this.context,
        MaterialPageRoute(
          builder: (context) => const WelcomePage(),
        ),
      );
    }
  }

  void _showBottomSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show bottom sheet for image source selection
  void _showImageSourceSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Use Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Browse Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick image from camera or gallery and upload to Supabase
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      // Upload the image to Supabase storage
      final file = File(image.path);
      final fileName =
          'resident_${residentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response = await Supabase.instance.client.storage
          .from('profileimages')
          .upload(fileName, file);

      if (response.isEmpty) {
        throw Exception('Failed to upload image');
      }

      // Get the public URL of the uploaded image
      final imageUrl = Supabase.instance.client.storage
          .from('profileimages')
          .getPublicUrl(fileName);

      // Update the resident's profile_image in the database
      await Supabase.instance.client
          .from('residents')
          .update({'profile_image': imageUrl}).eq('id', residentId!);

      // Update the local state to reflect the new image
      setState(() {
        _currentProfileImageUrl = imageUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile image: $e')),
        );
      }
    }
  }

  void _showEditProfileBottomSheet(BuildContext context) {
    // Reset edited states
    setState(() {
      _isFirstNameEdited = false;
      _isMiddleNameEdited = false;
      _isLastNameEdited = false;
      _isUsernameEdited = false;
      _isAgeEdited = false;
      _isAddressEdited = false;
      _isDateEdited = false;
      _isGenderEdited = false;
      _isStatusEdited = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the bottom sheet full-screen
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height *
                  0.9, // 90% of screen height
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Back Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 48), // Placeholder for alignment
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Profile Image Section
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageSourceSelection(context),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.grey[200],
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: (_currentProfileImageUrl != null &&
                                        _currentProfileImageUrl!.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: _currentProfileImageUrl!,
                                        imageBuilder:
                                            (context, imageProvider) =>
                                                Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showImageSourceSelection(context),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  backgroundColor: Colors.green,
                                  radius: 14,
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // First Name
                    const Text(
                      'First Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isFirstNameEdited = true;
                            });
                          },
                        ),
                        if (_isFirstNameEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Middle Name
                    const Text(
                      'Middle Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _middleNameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isMiddleNameEdited = true;
                            });
                          },
                        ),
                        if (_isMiddleNameEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Last Name
                    const Text(
                      'Last Name',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isLastNameEdited = true;
                            });
                          },
                        ),
                        if (_isLastNameEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Username
                    const Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isUsernameEdited = true;
                            });
                          },
                        ),
                        if (_isUsernameEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Age
                    const Text(
                      'Age',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isAgeEdited = true;
                            });
                          },
                        ),
                        if (_isAgeEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Date of Birth
                    const Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null && picked != _selectedDate) {
                              setModalState(() {
                                _selectedDate = picked;
                                _isDateEdited = true;
                                // Update age based on selected date
                                final now = DateTime.now();
                                int age = now.year - picked.year;
                                if (now.month < picked.month ||
                                    (now.month == picked.month &&
                                        now.day < picked.day)) {
                                  age--;
                                }
                                _ageController.text = age.toString();
                                _isAgeEdited = true;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate != null
                                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                      : 'Choose',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        if (_isDateEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Gender
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _selectedGender = 'Male';
                                    _isGenderEdited = true;
                                  });
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _selectedGender == 'Male'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _selectedGender == 'Male'
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Male'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _selectedGender = 'Female';
                                    _isGenderEdited = true;
                                  });
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _selectedGender == 'Female'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _selectedGender == 'Female'
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Female'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isGenderEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Address
                    const Text(
                      'Address',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _isAddressEdited = true;
                            });
                          },
                        ),
                        if (_isAddressEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status (Marital Status)
                    const Text(
                      'Marital Status',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Single', child: Text('Single')),
                            DropdownMenuItem(
                                value: 'Married', child: Text('Married')),
                            DropdownMenuItem(
                                value: 'Divorced', child: Text('Divorced')),
                            DropdownMenuItem(
                                value: 'Widowed', child: Text('Widowed')),
                            DropdownMenuItem(
                                value: 'Separated', child: Text('Separated')),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              _selectedStatus = value;
                              _isStatusEdited = true;
                            });
                          },
                          hint: const Text('Select Marital Status'),
                        ),
                        if (_isStatusEdited)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Save Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Update the resident data in the database
                          try {
                            await Supabase.instance.client
                                .from('residents')
                                .update({
                              'first_name': _firstNameController.text,
                              'middle_name': _middleNameController.text,
                              'last_name': _lastNameController.text,
                              'username': _usernameController.text,
                              'birth_date': _selectedDate?.toIso8601String(),
                              'gender': _selectedGender,
                              'address': _addressController.text,
                              'status': _selectedStatus,
                            }).eq('id', residentId!);

                            // Refresh the data after saving
                            await fetchResidentData();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Profile updated successfully')),
                              );

                              Navigator.pop(this.context);
                            } // Close the bottom sheet
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Error updating profile: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showImageSourceSelection(context),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.grey[200],
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: (_currentProfileImageUrl != null &&
                                      _currentProfileImageUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: _currentProfileImageUrl!,
                                      imageBuilder: (context, imageProvider) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: imageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showImageSourceSelection(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                radius: 14,
                                child: Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _fullName ?? widget.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Resident',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            residentAddress ?? 'No address available',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Horizontal Cards for Email and Phone
                  Center(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _showBottomSheet(
                                        context,
                                        'Email Address',
                                        residentEmail ?? 'N/A'),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.email,
                                        color: Colors.redAccent,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () => _showBottomSheet(context,
                                        'Phone Number', residentPhone ?? 'N/A'),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.phone,
                                        color: Colors.redAccent,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Edit Profile ListTile
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Colors.redAccent,
                      ),
                      title: const Text('Edit Profile'),
                      onTap: () => _showEditProfileBottomSheet(context),
                    ),
                  ),
                  // Sign Out ListTile
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
                      title: const Text('Sign Out'),
                      onTap: () => _signOut(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            alignment: Alignment.bottomCenter,
            child: Column(
              children: [
                Text(
                  'Alright Received',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'PSU-Quezon BSIT Students Capstone Project 2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
