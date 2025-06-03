import 'package:flutter/material.dart';

class FilterBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const FilterBottomSheet({super.key, required this.onSave});

  @override
  FilterBottomSheetState createState() => FilterBottomSheetState();
}

class FilterBottomSheetState extends State<FilterBottomSheet> {
  List<String> _selectedFields = []; // Default to unchecked

  // Reorderable lists for each section
  List<String> _identificationFields = [
    'id',
    'first_name',
    'last_name',
    'middle_name',
    'suffix_name',
    'username',
    'profile_image',
  ];
  List<String> _personalInfoFields = [
    'birth_date',
    'status',
    'gender',
  ];
  List<String> _contactInfoFields = [
    'personal_email',
    'phone',
    'address',
  ];

  // Methods to toggle selection for each section
  void _toggleSelectAllIdentification(bool? value) {
    setState(() {
      if (value == true) {
        _selectedFields.addAll(_identificationFields
            .where((field) => !_selectedFields.contains(field)));
      } else {
        _selectedFields
            .removeWhere((field) => _identificationFields.contains(field));
      }
    });
  }

  void _toggleSelectAllPersonalInfo(bool? value) {
    setState(() {
      if (value == true) {
        _selectedFields.addAll(_personalInfoFields
            .where((field) => !_selectedFields.contains(field)));
      } else {
        _selectedFields
            .removeWhere((field) => _personalInfoFields.contains(field));
      }
    });
  }

  void _toggleSelectAllContactInfo(bool? value) {
    setState(() {
      if (value == true) {
        _selectedFields.addAll(_contactInfoFields
            .where((field) => !_selectedFields.contains(field)));
      } else {
        _selectedFields
            .removeWhere((field) => _contactInfoFields.contains(field));
      }
    });
  }

  // Helper methods to check if all fields in a section are selected
  bool _areAllIdentificationSelected() {
    return _identificationFields
        .every((field) => _selectedFields.contains(field));
  }

  bool _areAllPersonalInfoSelected() {
    return _personalInfoFields
        .every((field) => _selectedFields.contains(field));
  }

  bool _areAllContactInfoSelected() {
    return _contactInfoFields.every((field) => _selectedFields.contains(field));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter properties',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Text(
            'Select properties that you want to see inside the exported file.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Identification Fields',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Checkbox(
                        value: _areAllIdentificationSelected(),
                        onChanged: _toggleSelectAllIdentification,
                        activeColor: Colors.redAccent,
                      ),
                    ],
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final field = _identificationFields.removeAt(oldIndex);
                        _identificationFields.insert(newIndex, field);
                      });
                    },
                    children: _identificationFields.map((field) {
                      return ListTile(
                        key: ValueKey(field),
                        title: Row(
                          children: [
                            Checkbox(
                              activeColor: Colors.redAccent,
                              value: _selectedFields.contains(field),
                              onChanged: (value) {
                                setState(() {
                                  if (value!) {
                                    _selectedFields.add(field);
                                  } else {
                                    _selectedFields.remove(field);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                field.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.drag_handle, size: 20),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Personal Info Fields',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Checkbox(
                        value: _areAllPersonalInfoSelected(),
                        onChanged: _toggleSelectAllPersonalInfo,
                        activeColor: Colors.redAccent,
                      ),
                    ],
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final field = _personalInfoFields.removeAt(oldIndex);
                        _personalInfoFields.insert(newIndex, field);
                      });
                    },
                    children: _personalInfoFields.map((field) {
                      return ListTile(
                        key: ValueKey(field),
                        title: Row(
                          children: [
                            Checkbox(
                              activeColor: Colors.redAccent,
                              value: _selectedFields.contains(field),
                              onChanged: (value) {
                                setState(() {
                                  if (value!) {
                                    _selectedFields.add(field);
                                  } else {
                                    _selectedFields.remove(field);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                field.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.drag_handle, size: 20),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Contact Info Fields',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Checkbox(
                        value: _areAllContactInfoSelected(),
                        onChanged: _toggleSelectAllContactInfo,
                        activeColor: Colors.redAccent,
                      ),
                    ],
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final field = _contactInfoFields.removeAt(oldIndex);
                        _contactInfoFields.insert(newIndex, field);
                      });
                    },
                    children: _contactInfoFields.map((field) {
                      return ListTile(
                        key: ValueKey(field),
                        title: Row(
                          children: [
                            Checkbox(
                              activeColor: Colors.redAccent,
                              value: _selectedFields.contains(field),
                              onChanged: (value) {
                                setState(() {
                                  if (value!) {
                                    _selectedFields.add(field);
                                  } else {
                                    _selectedFields.remove(field);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                field.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.drag_handle, size: 20),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          // Fixed footer outside the scrollable area
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3 total filters',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gilroy',
                          color: Colors.black87),
                    ),
                    Text(
                      '${_selectedFields.length} selected',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: () {
                      final filters = {
                        'selectedFields': _selectedFields,
                        'fieldOrder': {
                          'identification': _identificationFields,
                          'personalInfo': _personalInfoFields,
                          'contactInfo': _contactInfoFields,
                        },
                      };
                      widget.onSave(filters);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                    ),
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
