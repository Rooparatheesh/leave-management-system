import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddLeavePage extends StatefulWidget {
  final String empName;
  final String empId;
  final String designation;
  final String fla;
  final String sla;
   final String requestType;

  const AddLeavePage({
    Key? key,
    required this.empName,
    required this.empId,
    required this.designation,
    required this.fla,
    required this.sla,
    required this.requestType, 
  }) : super(key: key);

  @override
  State<AddLeavePage> createState() => _AddLeavePageState();
}

class _AddLeavePageState extends State<AddLeavePage> {
  static const Color primaryColor = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE55A2B);
  static const Color backgroundColor = Color(0xFFFFFBF7);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF666666);
  static const Color successColor = Color(0xFF388E3C);
  static const Color lightRed = Color(0xFFEF5350);

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> leaveTypes = [];
  int? selectedLeaveTypeId;
  String? selectedLeaveTypeName;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    fetchLeaveTypes();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> fetchLeaveTypes() async {
    try {
      final response = await http.get(Uri.parse('http://10.176.21.109:4000/api/leave-types'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          leaveTypes = data
              .map<Map<String, dynamic>>((item) => {
                    'id': item['id'],
                    'leave_type': item['leave_type'],
                  })
              .toList();
          if (leaveTypes.isNotEmpty) {
            selectedLeaveTypeId = leaveTypes[0]['id'];
            selectedLeaveTypeName = leaveTypes[0]['leave_type'];
          }
        });
      } else {
        _showSnackBar('Failed to load leave types', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error loading leave types', Colors.red);
    }
  }

Future<void> _submitLeaveRequest() async {
  if (!_formKey.currentState!.validate()) return;

  if (fromDate == null || toDate == null) {
    _showSnackBar('Please select valid dates', lightRed);
    return;
  }

  if ((selectedLeaveTypeName?.contains('Half Day') ?? false) && fromDate != toDate) {
    _showSnackBar('Half day leave must have same from and to date', lightRed);
    return;
  }

  final body = {
    "employee_id": widget.empId,
    "employee_name": widget.empName,
    "fla": widget.fla,
    "sla": widget.sla,
    "leave_type": selectedLeaveTypeName,
    "from_date": fromDate!.toIso8601String().split('T')[0],
    "to_date": toDate!.toIso8601String().split('T')[0],
    "in_time": null,
    "out_time": null,
    "reason": _reasonController.text.trim(),
    "remarks": "",
    "request_type": widget.requestType, 
  };

  try {
    final response = await http.post(
      Uri.parse('http://10.176.21.109:4000/api/leave-request'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      _showSnackBar('Leave request submitted successfully!', successColor);
      Future.delayed(const Duration(seconds: 2), () => Navigator.of(context).pop());
    } else {
      _showSnackBar('Failed to submit leave request', lightRed);
    }
  } catch (e) {
    _showSnackBar('Error submitting leave: $e', lightRed);
  }
}


  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Apply Leave',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Icon(Icons.help_outline, color: Colors.white),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.empName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'FLA: ${widget.fla}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'SLA: ${widget.sla}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedLeaveTypeId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: primaryColor),
                            items: leaveTypes.map((type) {
                              return DropdownMenuItem<int>(
                                value: type['id'],
                                child: Text(
                                  type['leave_type'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              setState(() {
                                selectedLeaveTypeId = newValue;
                                selectedLeaveTypeName = leaveTypes
                                    .firstWhere((e) => e['id'] == newValue)['leave_type'];
                                if (selectedLeaveTypeName!.contains('Half Day')) {
                                  toDate = fromDate;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'From Date',
                              fromDate,
                              () => _selectFromDate(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              'To Date',
                              toDate,
                              () => _selectToDate(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Note: Specific reason for availing leave must be stated rather than merely stating personal/work',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _reasonController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Enter reason for leave...',
                            hintStyle: TextStyle(color: textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter a reason for leave'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitLeaveRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Submit Leave Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 16,
                    color: date != null ? textPrimary : textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2000), 
      lastDate: DateTime(2100),  
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
        if (selectedLeaveTypeName?.contains('Half Day') ?? false) {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    if (fromDate == null) {
      _showSnackBar('Please select from date first', lightRed);
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? fromDate!,
      firstDate: fromDate!, 
      lastDate: DateTime(2100), 
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
      });
    }
  }
}