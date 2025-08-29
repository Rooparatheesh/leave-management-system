import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Top-level function for isolate
List<Map<String, dynamic>> decodeLeaveApplications(String data) {
  try {
    final jsonData = jsonDecode(data);

    if (jsonData is! List) {
      throw FormatException(
        'Expected a JSON list, got ${jsonData.runtimeType}',
      );
    }

    return jsonData.cast<Map<String, dynamic>>().map((item) {
      final fromDateStr = item['from_date']?.toString();
      final toDateStr = item['to_date']?.toString();
      final createdAtStr = item['created_at']?.toString();

      item['from_date'] = fromDateStr != null && fromDateStr.isNotEmpty
          ? DateTime.parse(fromDateStr).toLocal()
          : null;

      item['to_date'] = toDateStr != null && toDateStr.isNotEmpty
          ? DateTime.parse(toDateStr).toLocal()
          : null;

      item['created_at'] = createdAtStr != null && createdAtStr.isNotEmpty
          ? DateTime.tryParse(createdAtStr)?.toLocal()
          : null;

      return item;
    }).toList();
  } catch (e) {
    print('Error decoding leave applications: $e');
    rethrow;
  }
}

class AppColors {
  static const Color primaryColor = Color(0xFFFF6B35);
  static const Color backgroundColor = Color(0xFFFFFBF7);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF666666);
  static const Color successColor = Color(0xFF388E3C);
  static const Color lightRed = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color borderColor = Color(0xFFE9ECEF);
}

class StatusPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? token;

  const StatusPage({Key? key, required this.userData, this.token}) : super(key: key);

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<Map<String, dynamic>> leaveApplications = [];
  List<Map<String, dynamic>> cachedLeaveApplications = [];
  bool isLoading = true;
  bool isFetching = false;
  String? errorMessage;
  Timer? debounceTimer;
  Timer? loadingTimer;
  bool showLoadingMessage = false;
  bool? lastConnectivityResult;
  DateTime? lastConnectivityCheck;

  static const int maxRetries = 2;
  static const Duration timeoutDuration = Duration(seconds: 10);
  static const Duration debounceDuration = Duration(milliseconds: 600);
  static const String cacheKey = 'status_leave_requests';
  static const Duration connectivityCacheDuration = Duration(seconds: 5);

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  @override
  void initState() {
    super.initState();
    print('StatusPage initialized with empId: ${widget.userData['empId']}');
    _loadCachedData().then((_) => fetchLeaveRequestsWithDebounce());
    _startLoadingTimer();
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    loadingTimer?.cancel();
    super.dispose();
  }

  void _startLoadingTimer() {
    loadingTimer?.cancel();
    loadingTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && isLoading) {
        setState(() {
          showLoadingMessage = true;
        });
      }
    });
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null && mounted) {
      try {
        print('Cached data size: ${cachedData.length} bytes');
        final decodedData = await compute(decodeLeaveApplications, cachedData);
        setState(() {
          cachedLeaveApplications = decodedData;
          leaveApplications = cachedLeaveApplications;
          isLoading = false;
        });
        print('Loaded ${decodedData.length} cached leave applications');
      } catch (e) {
        print('Error loading cached data: $e');
        setState(() {
          errorMessage = 'Failed to load cached data: $e';
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveCachedData(List<Map<String, dynamic>> applications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(applications));
    print('Saved ${applications.length} leave applications to cache');
  }

  Future<bool> _checkConnectivity() async {
    final now = DateTime.now();
    if (lastConnectivityCheck != null &&
        now.difference(lastConnectivityCheck!) < connectivityCacheDuration &&
        lastConnectivityResult != null) {
      return lastConnectivityResult!;
    }

    var connectivityResult = await Connectivity().checkConnectivity();
    lastConnectivityResult = connectivityResult != ConnectivityResult.none;
    lastConnectivityCheck = now;

    return lastConnectivityResult!;
  }

  void fetchLeaveRequestsWithDebounce() {
    if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
    debounceTimer = Timer(debounceDuration, () {
      fetchLeaveRequests();
    });
  }

  Future<void> fetchLeaveRequests({int retryCount = 0}) async {
    if (isFetching) {
      print('Fetch already in progress, skipping');
      return;
    }
    isFetching = true;

    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
      showLoadingMessage = false;
    });
    _startLoadingTimer();

    try {
      final employeeId = widget.userData['empId']?.toString().trim();
      final authToken = widget.token ?? await getAuthToken();
      
      if (employeeId == null || employeeId.isEmpty) {
        setState(() {
          errorMessage = 'Invalid employee ID. Please log in again.';
          isLoading = false;
          leaveApplications = cachedLeaveApplications;
        });
        return;
      }

      if (!await _checkConnectivity()) {
        setState(() {
          errorMessage = 'No internet connection. Showing cached data.';
          isLoading = false;
          leaveApplications = cachedLeaveApplications;
        });
        return;
      }

      if (authToken == null || authToken.isEmpty) {
        setState(() {
          errorMessage = 'Authentication token missing. Please log in again.';
          isLoading = false;
          leaveApplications = cachedLeaveApplications;
        });
        return;
      }

      print('Fetching leave requests for empId: $employeeId, Attempt: ${retryCount + 1}');
      final response = await http
          .get(
            Uri.parse('http://10.176.21.109:4000/api/leave-request/$employeeId'),
            headers: {
              'Content-Type': 'application/json',
              'Connection': 'close',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(timeoutDuration, onTimeout: () {
        throw TimeoutException('Request timed out after ${timeoutDuration.inSeconds}s.');
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('API response size: ${response.body.length} bytes');
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] == true) {
          final data = jsonData['data'] as List<dynamic>?;
          if (data != null) {
            final decodedData = await compute(decodeLeaveApplications, jsonEncode(data));
            setState(() {
              leaveApplications = decodedData;
              cachedLeaveApplications = leaveApplications;
              _saveCachedData(leaveApplications);
              isLoading = false;
            });
            print('Fetched ${leaveApplications.length} leave applications');
          } else {
            setState(() {
              errorMessage = 'No leave data found. Showing cached data.';
              isLoading = false;
              leaveApplications = cachedLeaveApplications;
            });
          }
        } else {
          if (retryCount < maxRetries - 1) {
            final delay = Duration(milliseconds: 1000 * (retryCount + 1));
            print('Fetch retry ${retryCount + 1} failed with status: ${response.statusCode}');
            await Future.delayed(delay);
            return fetchLeaveRequests(retryCount: retryCount + 1);
          }
          setState(() {
            errorMessage = jsonData['error'] ?? 'Failed to fetch leave requests.';
            isLoading = false;
            leaveApplications = cachedLeaveApplications;
          });
        }
      } else {
        if (retryCount < maxRetries - 1) {
          final delay = Duration(milliseconds: 1000 * (retryCount + 1));
          print('Fetch retry ${retryCount + 1} failed with status: ${response.statusCode}');
          await Future.delayed(delay);
          return fetchLeaveRequests(retryCount: retryCount + 1);
        }
        setState(() {
          errorMessage = 'Server error: HTTP ${response.statusCode} - ${response.reasonPhrase}';
          isLoading = false;
          leaveApplications = cachedLeaveApplications;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (retryCount < maxRetries - 1 && (e is TimeoutException || e is http.ClientException)) {
        final delay = Duration(milliseconds: 1000 * (retryCount + 1));
        print('Fetch retry ${retryCount + 1} due to error: $e');
        await Future.delayed(delay);
        return fetchLeaveRequests(retryCount: retryCount + 1);
      }
      setState(() {
        errorMessage = e is TimeoutException
            ? 'Request timed out after ${timeoutDuration.inSeconds}s. Showing cached data.'
            : e is http.ClientException
                ? 'Network error: Please check your connection'
                : 'Fetch error: $e';
        isLoading = false;
        leaveApplications = cachedLeaveApplications;
      });
    } finally {
      isFetching = false;
      loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          showLoadingMessage = false;
        });
      }
    }
  }

Future<void> _cancelLeave(int? leaveId) async {
  if (leaveId == null) {
    _showSnackBar('Invalid leave ID.', AppColors.lightRed);
    return;
  }

  // Confirm dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Cancellation'),
      content: const Text('Are you sure you want to cancel this leave request?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
      ],
    ),
  );

  if (confirm != true) return;

  if (!await _checkConnectivity()) {
    _showSnackBar('No internet connection. Cannot cancel leave.', AppColors.lightRed);
    return;
  }

  final authToken = widget.token ?? await getAuthToken();
  if (authToken == null || authToken.isEmpty) {
    _showSnackBar('Authentication token missing. Please log in again.', AppColors.lightRed);

    // Clear session and navigate to login
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) Navigator.pushReplacementNamed(context, '/login');
    return;
  }

  try {
    setState(() => isLoading = true);

    final response = await http.put(
      Uri.parse('http://10.176.21.109:4000/api/leave-request/cancel/$leaveId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    ).timeout(timeoutDuration);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      setState(() {
        leaveApplications = leaveApplications.map((leave) {
          if (leave['id'] == leaveId) {
            return {...leave, 'status': 'Cancelled'};
          }
          return leave;
        }).toList();
        cachedLeaveApplications = leaveApplications;
        _saveCachedData(leaveApplications);
      });
      _showSnackBar('Leave cancelled successfully', AppColors.successColor);
    } else {
      final error = data['error'] ?? 'Failed to cancel leave';
      _showSnackBar(error, AppColors.lightRed);
    }
  } catch (e) {
    _showSnackBar('Error cancelling leave: $e', AppColors.lightRed);
  } finally {
    setState(() => isLoading = false);
  }
}

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      title: const Text(
        'Leave Applications',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      actions: [
        IconButton(
          onPressed: isLoading || isFetching ? null : fetchLeaveRequestsWithDebounce,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading && cachedLeaveApplications.isEmpty) {
      return _buildSkeletonScreen();
    }

    if (errorMessage != null && cachedLeaveApplications.isEmpty) {
      return _buildErrorState();
    }

    if (leaveApplications.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildSummaryBar(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryColor,
            onRefresh: fetchLeaveRequests,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: leaveApplications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildLeaveCard(leaveApplications[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonScreen() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          color: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 100, height: 14, color: Colors.grey[300]),
                    Container(width: 80, height: 24, color: Colors.grey[300]),
                  ],
                ),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 14, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 14, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 14, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 14, color: Colors.grey[300]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardColor,
        border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Text(
        'Total Applications: ${leaveApplications.length}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.lightRed.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (showLoadingMessage)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Still loading, please wait...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isFetching ? null : fetchLeaveRequestsWithDebounce,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                if (errorMessage!.contains('employee ID') || errorMessage!.contains('token'))
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Applications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You haven\'t submitted any leave applications yet.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: isLoading || isFetching ? null : fetchLeaveRequestsWithDebounce,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final fromDate = leave['from_date'] as DateTime?;
    final toDate = leave['to_date'] as DateTime?;
    final appliedDate = leave['created_at'] as DateTime?;

    if (fromDate == null || toDate == null || appliedDate == null) {
      return Card(
        elevation: 2,
        color: AppColors.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Invalid date data for this leave application.',
            style: TextStyle(color: AppColors.lightRed),
          ),
        ),
      );
    }

    final duration = toDate.difference(fromDate).inDays + 1;

    return Card(
      elevation: 2,
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${leave['id'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildStatusChip(leave['status'] ?? 'Unknown'),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Employee', leave['employee_name'] ?? 'N/A'),
            _buildInfoRow('Leave Type', leave['leave_type'] ?? 'N/A'),
            _buildInfoRow('Duration', '$duration day(s)'),
            _buildInfoRow('From', _formatDate(fromDate)),
            _buildInfoRow('To', _formatDate(toDate)),
            if (leave['request_type'] == 'outdoor') ...[
              _buildInfoRow('In Time', leave['in_time'] ?? 'N/A'),
              _buildInfoRow('Out Time', leave['out_time'] ?? 'N/A'),
            ],
            _buildInfoRow('Applied', _formatDate(appliedDate)),
            if (leave['reason']?.toString().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Reason',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                leave['reason'],
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
            if (leave['remarks']?.toString().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                leave['remarks'],
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(height: 12),
            if (leave['status'].toString().toLowerCase() == 'pending') ...[
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => _cancelLeave(leave['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Cancel Leave',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = AppColors.successColor;
        textColor = Colors.white;
        break;
      case 'pending':
        backgroundColor = AppColors.warningColor;
        textColor = Colors.black87;
        break;
      case 'rejected':
        backgroundColor = AppColors.lightRed;
        textColor = Colors.white;
        break;
      case 'cancelled':
        backgroundColor = AppColors.textSecondary;
        textColor = Colors.white;
        break;
      default:
        backgroundColor = AppColors.textSecondary;
        textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}