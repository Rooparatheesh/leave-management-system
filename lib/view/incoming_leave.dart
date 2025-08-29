import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Custom Color Scheme
class AppColors {
  static const Color primaryColor = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE55A2B);
  static const Color backgroundColor = Color(0xFFFFFBF7);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF666666);
  static const Color successColor = Color(0xFF388E3C);
  static const Color accentOrange = Color(0xFFFFF3E0);
  static const Color lightBlue = Color(0xFF4FC3F7);
  static const Color lightRed = Color(0xFFEF5350);
  static const Color purpleColor = Color(0xFF9C27B0);
  static const Color warningColor = Color(0xFFFF9800);
}

class IncomingLeaveRequestPage extends StatefulWidget {
  final int roleId;
  final String userName;
  final String empId;

  const IncomingLeaveRequestPage({
    super.key,
    required this.roleId,
    required this.userName,
    required this.empId,
  });

  @override
  _IncomingLeaveRequestPageState createState() => _IncomingLeaveRequestPageState();
}

class _IncomingLeaveRequestPageState extends State<IncomingLeaveRequestPage> {
  List<LeaveRequest> leaveRequests = [];
  bool isLoading = true;
  String? errorMessage;
  final String baseUrl = 'http://10.176.21.109:4000';

  @override
  void initState() {
    super.initState();
    fetchIncomingLeaves();
  }

  Future<void> fetchIncomingLeaves() async {
    try {
      final String apiUrl = '$baseUrl/api/incoming-leaves?empId=${widget.empId}';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // Filter out "Cancelled", "Rejected by GH", and "Approved by GH" statuses
          leaveRequests = data
              .map((json) => LeaveRequest.fromJson(json))
              .where((request) => !['cancelled', 'rejected by gh', 'approved by gh'].contains(request.status.toLowerCase()))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  void removeLeaveRequest(String leaveId) {
    setState(() {
      leaveRequests.removeWhere((request) => request.id == leaveId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Leave Requests'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!, style: const TextStyle(color: AppColors.lightRed)))
                : RefreshIndicator(
                    onRefresh: fetchIncomingLeaves,
                    child: leaveRequests.isEmpty
                        ? const Center(child: Text('No leave requests found', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: leaveRequests.length,
                            itemBuilder: (context, index) {
                              return LeaveRequestCard(
                                leaveRequest: leaveRequests[index],
                                currentEmpId: widget.empId,
                                baseUrl: baseUrl,
                                onStatusChanged: (newStatus, newRemark, leaveId) {
                                  // Remove the leave request if the new status is "Approved" or "Rejected"
                                  if (['approved', 'rejected', 'approved by gh', 'rejected by gh'].contains(newStatus.toLowerCase())) {
                                    removeLeaveRequest(leaveId);
                                  }
                                },
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class LeaveRequestCard extends StatefulWidget {
  final LeaveRequest leaveRequest;
  final String currentEmpId;
  final String baseUrl;
  final Function(String status, String? remark, String leaveId) onStatusChanged;

  const LeaveRequestCard({
    super.key,
    required this.leaveRequest,
    required this.currentEmpId,
    required this.baseUrl,
    required this.onStatusChanged,
  });

  @override
  _LeaveRequestCardState createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<LeaveRequestCard> {
  TextEditingController remarkController = TextEditingController();
  bool showRemarkField = false;
  String? actionType;

  String formatDate(DateTime date) {
    // Format date to display as DD/MM/YYYY, ensuring date-only display
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int calculateLeaveDays() {
    // Calculate duration based on date-only values
    final start = DateTime(widget.leaveRequest.startDate.year, widget.leaveRequest.startDate.month, widget.leaveRequest.startDate.day);
    final end = DateTime(widget.leaveRequest.endDate.year, widget.leaveRequest.endDate.month, widget.leaveRequest.endDate.day);
    return end.difference(start).inDays + 1;
  }

  Future<void> handleRecommend() async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/leave-requests/${widget.leaveRequest.id}/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'FLA Recommended',
          'empId': widget.currentEmpId,
        }),
      );

      if (response.statusCode == 200) {
        widget.onStatusChanged('FLA Recommended', null, widget.leaveRequest.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request recommended successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to recommend';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.lightRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.lightRed,
        ),
      );
    }
  }

  void handleNotRecommend() {
    setState(() {
      showRemarkField = true;
      actionType = 'not_recommend';
      remarkController.clear();
    });
  }

  Future<void> handleApprove() async {
    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/leave-requests/${widget.leaveRequest.id}/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'empId': widget.currentEmpId,
        }),
      );

      if (response.statusCode == 200) {
        widget.onStatusChanged('Approved by GH', null, widget.leaveRequest.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request approved successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to approve';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.lightRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.lightRed,
        ),
      );
    }
  }

  void handleDecline() {
    setState(() {
      showRemarkField = true;
      actionType = 'reject';
      remarkController.clear();
    });
  }

  Future<void> submitRemark() async {
    final remark = remarkController.text.trim();
    if (remark.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a remark'),
          backgroundColor: AppColors.lightRed,
        ),
      );
      return;
    }

    try {
      String endpoint;
      String newStatus;
      String successMessage;
      String errorMessage;

      if (actionType == 'not_recommend') {
        endpoint = '/api/leave-requests/${widget.leaveRequest.id}/not-recommend';
        newStatus = 'FLA Not Recommended';
        successMessage = 'Leave request not recommended successfully';
        errorMessage = 'Failed to not recommend';
      } else if (actionType == 'reject') {
        endpoint = '/api/leave-requests/${widget.leaveRequest.id}/reject';
        newStatus = 'Rejected by GH';
        successMessage = 'Leave request declined successfully';
        errorMessage = 'Failed to decline';
      } else {
        return;
      }

      final response = await http.put(
        Uri.parse('${widget.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'empId': widget.currentEmpId,
          'reason': remark,
        }),
      );

      if (response.statusCode == 200) {
        widget.onStatusChanged(newStatus, remark, widget.leaveRequest.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.warningColor,
          ),
        );
        setState(() {
          showRemarkField = false;
          remarkController.clear();
        });
      } else {
        final error = json.decode(response.body)['error'] ?? errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.lightRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.lightRed,
        ),
      );
    }
  }

  Color getStatusColor() {
    switch (widget.leaveRequest.status.toLowerCase()) {
      case 'fla recommended':
        return AppColors.lightBlue;
      case 'fla not recommended':
        return AppColors.warningColor;
      case 'approved':
      case 'approved by gh':
        return AppColors.successColor;
      case 'rejected':
      case 'rejected by gh':
        return AppColors.lightRed;
      case 'pending':
      default:
        return AppColors.textSecondary;
    }
  }

  String getStatusText() {
    return widget.leaveRequest.status.toUpperCase();
  }

  bool get canShowFlaActions {
    return widget.leaveRequest.status.toLowerCase() == 'pending' &&
        !widget.leaveRequest.isSameApprover &&
        widget.currentEmpId == widget.leaveRequest.flaEmpId;
  }

  bool get canShowSlaOrGhActions {
    if (widget.leaveRequest.isSameApprover) {
      return widget.leaveRequest.status.toLowerCase() == 'pending' &&
          (widget.currentEmpId == widget.leaveRequest.slaEmpId ||
              widget.currentEmpId == widget.leaveRequest.ghEmpId);
    } else {
      return (widget.leaveRequest.status.toLowerCase() == 'fla recommended' ||
              widget.leaveRequest.status.toLowerCase() == 'fla not recommended') &&
          (widget.currentEmpId == widget.leaveRequest.slaEmpId ||
              widget.currentEmpId == widget.leaveRequest.ghEmpId);
    }
  }

  String get remarkTitle {
    if (actionType == 'not_recommend') {
      return 'Reason for not recommending:';
    } else if (actionType == 'reject') {
      return 'Reason for declining:';
    }
    return 'Reason:';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with employee info and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.leaveRequest.employeeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.leaveRequest.employeeId}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: getStatusColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Leave details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('Leave Type: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(widget.leaveRequest.leaveType, style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('Duration: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text('${formatDate(widget.leaveRequest.startDate)} - ${formatDate(widget.leaveRequest.endDate)}', style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('Days: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text('${calculateLeaveDays()} days', style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('Reason: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Expanded(child: Text(widget.leaveRequest.reason, style: const TextStyle(color: AppColors.textPrimary))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('FLA Name: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(widget.leaveRequest.flaName ?? 'N/A', style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('SLA Name: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(widget.leaveRequest.slaName ?? 'N/A', style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      const Text('GH Name: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      Text(widget.leaveRequest.ghName ?? 'N/A', style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            if (canShowFlaActions) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: handleRecommend,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Recommend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: handleNotRecommend,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Not Recommend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lightRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (canShowSlaOrGhActions) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: handleApprove,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: handleDecline,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Decline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lightRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Remark field
            if (showRemarkField) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: AppColors.lightRed.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remarkTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.lightRed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please provide a detailed reason...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              showRemarkField = false;
                              remarkController.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: submitRemark,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightRed,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // Show remark if applicable
            if ((widget.leaveRequest.status.toLowerCase() == 'fla not recommended' ||
                    widget.leaveRequest.status.toLowerCase() == 'rejected' ||
                    widget.leaveRequest.status.toLowerCase() == 'rejected by gh') &&
                widget.leaveRequest.remark != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: AppColors.lightRed.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.comment, size: 16, color: AppColors.lightRed),
                        SizedBox(width: 8),
                        Text(
                          'Remark:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.lightRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.leaveRequest.remark!,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LeaveRequest {
  final String id;
  final String employeeName;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final DateTime requestDate;
  String status;
  String? remark;
  final String flaEmpId;
  final String slaEmpId;
  final String ghEmpId;
  final String? flaName;
  final String? slaName;
  final String? ghName;
  final bool isSameApprover;

  LeaveRequest({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.requestDate,
    required this.flaEmpId,
    required this.slaEmpId,
    required this.ghEmpId,
    required this.isSameApprover,
    this.flaName,
    this.slaName,
    this.ghName,
    required this.status,
    this.remark,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String dateStr) {
      // Log the raw date string for debugging
      print('Parsing date: $dateStr');
      // Extract only the YYYY-MM-DD part, ignoring time and timezone
      final dateParts = dateStr.split('T')[0].split('-');
      if (dateParts.length == 3) {
        try {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          // Create a DateTime object as a local date in IST and adjust by adding one day
          // to match the database date (temporary workaround for API mismatch)
          final date = DateTime(year, month, day);
          return date.add(const Duration(days: 1));
        } catch (e) {
          print('Error parsing date $dateStr: $e');
          return DateTime.now(); // Fallback to current date
        }
      }
      print('Invalid date format: $dateStr');
      return DateTime.now(); // Fallback to current date
    }

    return LeaveRequest(
      id: json['leave_id'].toString(),
      employeeName: json['applicant_name'],
      employeeId: json['applicant_emp_id'].toString(),
      leaveType: json['leave_type'],
      startDate: parseDate(json['from_date']),
      endDate: parseDate(json['to_date']),
      reason: json['reason'],
      requestDate: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()).toLocal(),
      status: json['status'] ?? 'Pending',
      remark: json['remarks'],
      flaEmpId: json['fla_emp_id'].toString(),
      slaEmpId: json['sla_emp_id'].toString(),
      ghEmpId: json['gh_emp_id'].toString(),
      flaName: json['fla_name'],
      slaName: json['sla_name'],
      ghName: json['gh_name'],
      isSameApprover: json['is_same_approver'] == true || json['is_same_approver'] == 1,
    );
  }
}