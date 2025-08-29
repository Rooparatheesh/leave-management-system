import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ViewAllLeavesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ViewAllLeavesPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<ViewAllLeavesPage> createState() => _ViewAllLeavesPageState();
}

class _ViewAllLeavesPageState extends State<ViewAllLeavesPage> {
  // Color Palette
  static const Color primaryColor = Color(0xFFFF6B35);
  static const Color backgroundColor = Color(0xFFFFFBF7);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF666666);
  static const Color successColor = Color(0xFF388E3C);
  static const Color accentOrange = Color(0xFFFFF3E0);
  static const Color lightBlue = Color(0xFF4FC3F7);
  static const Color lightRed = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFF9800);

  List<Map<String, dynamic>> allLeaveRequests = [];
  Map<String, List<Map<String, dynamic>>> groupedLeaves = {};
  bool isLoading = true;
  String? errorMessage;
  String selectedFilter = 'All';
  Set<int> processedLeaveIds = {}; // Track leaves that have been processed

  // API endpoint
  final String apiUrl = 'http://10.176.21.109:4000/api/leave-requests';
  final String updateStatusUrl = 'http://10.176.21.109:4000/api/leave/update-status';

  late Map<String, dynamic> userData;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    fetchLeaveRequests();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchLeaveRequests() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // Add authentication headers if needed
          // 'Authorization': 'Bearer your-token-here',
        },
      );

      print('Fetch Leave Requests Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          allLeaveRequests = data.map((item) => Map<String, dynamic>.from(item)).toList();
          
          // Sort allLeaveRequests by created_at in descending order (latest first)
          allLeaveRequests.sort((a, b) {
            String? dateA = a['created_at'];
            String? dateB = b['created_at'];
            
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            
            try {
              DateTime parsedDateA = DateTime.parse(dateA).toLocal();
              DateTime parsedDateB = DateTime.parse(dateB).toLocal();
              return parsedDateB.compareTo(parsedDateA); // Descending order (latest first)
            } catch (e) {
              return 0;
            }
          });
          
          groupLeavesByMonth();
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Failed to load leave requests. Status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> approveLeave(int leaveId) async {
    try {
      final response = await http.post(
        Uri.parse(updateStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          // Add authentication headers if needed
          // 'Authorization': 'Bearer your-token-here',
        },
        body: json.encode({
          'leave_id': leaveId,
          'action': 'approve',
        }),
      );

      print('Approve Leave Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (!mounted) return;
          setState(() {
            for (var leave in allLeaveRequests) {
              if (leave['id'] == leaveId) {
                leave['status'] = 'approved';
                leave['remarks'] = responseData['data']['remarks'] ?? 'Approved by GH';
                break;
              }
            }
            // Add to processed leaves to hide buttons
            processedLeaveIds.add(leaveId);
            groupLeavesByMonth();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Leave approved successfully'),
              backgroundColor: successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error parsing response: $e'),
              backgroundColor: lightRed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve leave. Status: ${response.statusCode}'),
            backgroundColor: lightRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving leave: $e'),
          backgroundColor: lightRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> rejectLeave(int leaveId) async {
    String? reason = await _showReasonDialog('Reject Leave', 'Please provide a reason for rejection:');

    if (reason == null || reason.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rejection reason is required'),
          backgroundColor: warningColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(updateStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          // Add authentication headers if needed
          // 'Authorization': 'Bearer your-token-here',
        },
        body: json.encode({
          'leave_id': leaveId,
          'action': 'reject',
          'reason': reason.trim(),
        }),
      );

      print('Reject Leave Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          if (!mounted) return;
          setState(() {
            for (var leave in allLeaveRequests) {
              if (leave['id'] == leaveId) {
                leave['status'] = 'rejected';
                leave['remarks'] = responseData['data']['remarks'] ?? 'Rejected: ${reason.trim()}';
                break;
              }
            }
            // Add to processed leaves to hide buttons
            processedLeaveIds.add(leaveId);
            groupLeavesByMonth();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Leave rejected successfully'),
              backgroundColor: lightRed,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error parsing response: $e'),
              backgroundColor: lightRed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject leave. Status: ${response.statusCode}'),
            backgroundColor: lightRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting leave: $e'),
          backgroundColor: lightRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _showReasonDialog(String title, String content) async {
    TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(reasonController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void groupLeavesByMonth() {
    groupedLeaves.clear();

    for (var leave in allLeaveRequests) {
      if (selectedFilter != 'All' && leave['status']?.toLowerCase() != selectedFilter.toLowerCase()) {
        continue;
      }

      String? createdAt = leave['created_at'];
      if (createdAt != null) {
        DateTime date = DateTime.parse(createdAt).toLocal();
        String monthYear = DateFormat('MMMM yyyy').format(date);

        if (!groupedLeaves.containsKey(monthYear)) {
          groupedLeaves[monthYear] = [];
        }
        groupedLeaves[monthYear]!.add(leave);
      }
    }

    // Sort months in descending order (latest first)
    final sortedKeys = groupedLeaves.keys.toList()
      ..sort((a, b) {
        DateTime dateA = DateFormat('MMMM yyyy').parse(a);
        DateTime dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA); // Latest month first
      });

    // Sort leaves within each month by created_at in descending order (latest first)
    Map<String, List<Map<String, dynamic>>> sortedGroupedLeaves = {};
    for (String key in sortedKeys) {
      List<Map<String, dynamic>> monthLeaves = groupedLeaves[key]!;
      monthLeaves.sort((a, b) {
        String? dateA = a['created_at'];
        String? dateB = b['created_at'];
        
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        try {
          DateTime parsedDateA = DateTime.parse(dateA).toLocal();
          DateTime parsedDateB = DateTime.parse(dateB).toLocal();
          return parsedDateB.compareTo(parsedDateA); // Latest first within month
        } catch (e) {
          return 0;
        }
      });
      sortedGroupedLeaves[key] = monthLeaves;
    }
    groupedLeaves = sortedGroupedLeaves;
  }

  Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return successColor;
      case 'pending':
        return warningColor;
      case 'rejected':
        return lightRed;
      case 'cancelled':
        return textSecondary;
      default:
        return textSecondary;
    }
  }

  Icon getLeaveTypeIcon(String? leaveType) {
    switch (leaveType?.toLowerCase()) {
      case 'sick':
        return const Icon(Icons.local_hospital, color: lightRed, size: 20);
      case 'casual':
        return const Icon(Icons.weekend, color: lightBlue, size: 20);
      case 'annual':
        return const Icon(Icons.calendar_month, color: successColor, size: 20);
      case 'emergency':
        return const Icon(Icons.emergency, color: warningColor, size: 20);
      default:
        return const Icon(Icons.event_note, color: textSecondary, size: 20);
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      DateTime date;
      if (dateStr.contains('T')) {
        // If it's a full datetime string, parse it
        date = DateTime.parse(dateStr);
        // Convert to local timezone to get the correct date
        date = date.toLocal();
      } else {
        // If it's just a date string (YYYY-MM-DD), treat it as local date
        date = DateTime.parse(dateStr + 'T00:00:00');
      }
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatTime(String? timeStr) {
    if (timeStr == null) return 'N/A';
    try {
      List<String> parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        TimeOfDay time = TimeOfDay(hour: hour, minute: minute);
        return time.format(context);
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  Widget buildFilterChips() {
   List<String> filters = ['All', 'Pending', 'Approved', 'Rejected', 'Approved by GH', 'Rejected by GH', 'Cancelled'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          String filter = filters[index];
          bool isSelected = selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (!mounted) return;
                setState(() {
                  selectedFilter = filter;
                  groupLeavesByMonth();
                });
              },
              selectedColor: primaryColor.withOpacity(0.2),
              checkmarkColor: primaryColor,
              backgroundColor: cardColor,
              labelStyle: TextStyle(
                color: isSelected ? primaryColor : textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildActionButtons(Map<String, dynamic> leave) {
    String status = (leave['status'] ?? '').toString().toLowerCase().trim();
    int leaveId = leave['id'] ?? 0;

    // Hide buttons if this leave has been processed
    if (processedLeaveIds.contains(leaveId)) {
      return const SizedBox.shrink();
    }

    // Show buttons only for approved and rejected status
    // Hide buttons for pending and cancelled status
    if (status == 'pending' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

    // Show buttons for approved and rejected leaves
    if (status == 'approved' || status == 'rejected') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  approveLeave(leave['id']);
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  rejectLeave(leave['id']);
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For any other status, hide buttons
    return const SizedBox.shrink();
  }

  Widget buildLeaveCard(Map<String, dynamic> leave) {
    String status = leave['status'] ?? 'Unknown';
    String leaveType = leave['leave_type'] ?? 'N/A';
    String employeeName = leave['employee_name'] ?? 'N/A';
    String fromDate = formatDate(leave['from_date']);
    String toDate = formatDate(leave['to_date']);
    String reason = leave['reason'] ?? 'No reason provided';
    String outTime = formatTime(leave['out_time']);
    String inTime = formatTime(leave['in_time']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      getLeaveTypeIcon(leaveType),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: getStatusColor(status), width: 1),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leave Type',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          leaveType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lightBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$fromDate - $toDate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (leave['out_time'] != null || leave['in_time'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (leave['out_time'] != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.logout, size: 16, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Out: $outTime',
                            style: const TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  if (leave['in_time'] != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.login, size: 16, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'In: $inTime',
                            style: const TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Reason:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 14,
                color: textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (leave['remarks'] != null && leave['remarks'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leave['remarks'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            buildActionButtons(leave),
          ],
        ),
      ),
    );
  }

  Widget buildMonthSection(String month, List<Map<String, dynamic>> leaves) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                month,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${leaves.length} ${leaves.length == 1 ? 'Request' : 'Requests'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...leaves.map((leave) => buildLeaveCard(leave)).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'All Leave Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchLeaveRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          buildFilterChips(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: lightRed,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error Loading Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchLeaveRequests,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : groupedLeaves.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: textSecondary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No Leave Requests Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'There are no leave requests matching your filter.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchLeaveRequests,
                            color: primaryColor,
                            child: ListView.builder(
                              itemCount: groupedLeaves.keys.length,
                              itemBuilder: (context, index) {
                                String month = groupedLeaves.keys.elementAt(index);
                                List<Map<String, dynamic>> leaves = groupedLeaves[month]!;
                                return buildMonthSection(month, leaves);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}