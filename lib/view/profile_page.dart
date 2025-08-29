import 'package:flutter/material.dart';
import 'package:leave_management1/view/add_leave_page.dart';
import 'package:leave_management1/view/incoming_leave.dart';
import 'package:leave_management1/view/outdoor_duty.dart';
import 'package:leave_management1/view/status.dart';
import 'package:leave_management1/view/view_all_leaves.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfilePage({Key? key, required this.userData}) : super(key: key);
  final String baseUrl = 'http://10.176.21.109:4000';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
  static const Color warningColor = Color(0xFFFF9800);

  int roleId = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    setState(() {
      _isLoading = true;
    });

    _userData = Map<String, dynamic>.from(widget.userData);
    roleId = int.tryParse(_userData['role_id']?.toString() ?? '0') ?? 0;

    print('Initial widget.userData: $_userData');
    print('Initial roleId: $roleId');

    if (_userData.isEmpty || roleId == 0 || !_userData.containsKey('empId')) {
      print('widget.userData is empty or invalid, checking SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final storedUserData = prefs.getString('userData');

      if (isLoggedIn && storedUserData != null && storedUserData.isNotEmpty) {
        try {
          final decodedData = json.decode(storedUserData) as Map<String, dynamic>;
          if (decodedData.containsKey('role_id') && decodedData.containsKey('empId')) {
            setState(() {
              _userData = decodedData;
              roleId = int.tryParse(decodedData['role_id']?.toString() ?? '0') ?? 0;
            });
            print('Updated userData from SharedPreferences: $_userData');
            print('Updated roleId: $roleId');
          } else {
            print('Stored userData is missing required fields');
            _showErrorMessage('Invalid user data in storage. Please log in again.');
            await Future.delayed(const Duration(seconds: 2));
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }
        } catch (e) {
          print('Error decoding stored userData: $e');
          _showErrorMessage('Failed to load user data from storage.');
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      } else {
        print('No valid session or userData found');
        _showErrorMessage('Please log in to continue.');
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    }

    await _fetchLeaveCounts();
    setState(() {
      _isLoading = false;
    });

    print('Final ProfilePage userData: $_userData');
    print('Final ProfilePage roleId: $roleId');
    print('Final ProfilePage empId: ${_userData['empId']}');
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('isLoggedIn', false);
    print('Logged out, cleared SharedPreferences');
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: lightRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchLeaveCounts() async {
    final empId = _userData['empId']?.toString();
    if (empId == null || empId.isEmpty) {
      print('No empId available');
      _showErrorMessage('Employee ID not available.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/leave-counts/$empId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> counts = json.decode(response.body);
        setState(() {
          _approvedCount = counts['approved'] ?? 0;
          _rejectedCount = counts['rejected'] ?? 0;
        });
      } else {
        print('Failed to load leave counts: ${response.statusCode}');
        _showErrorMessage('Failed to load leave counts.');
      }
    } catch (e) {
      print('Error fetching leave counts: $e');
      _showErrorMessage('Error fetching leave counts.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthlyLeaveStats(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: accentOrange,
                        child: const Icon(Icons.person, size: 40, color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData['designation'] ?? 'No Designation',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${_userData['empId'] ?? 'N/A'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildMonthlyLeaveStats() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'This Month Statistics',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildStatCard('5', 'Leave Applied', 'This Month', primaryColor, Icons.event_note),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('2', 'Outdoor Duty', 'Applied', lightBlue, Icons.directions_walk),
          ),
          if (roleId == 1 || roleId == 2 || roleId == 4) ...[
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final userName = _userData['name']?.toString();
                  final empId = _userData['empId']?.toString();
                  if (userName != null && userName.isNotEmpty && empId != null && empId.isNotEmpty) {
                    print('Navigating to IncomingLeavePage with empId: $empId');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncomingLeaveRequestPage(
                          roleId: roleId,
                          userName: userName,
                          empId: empId,
                        ),
                      ),
                    );
                  } else {
                    _showErrorMessage('User data not available for navigation.');
                  }
                },
                child: _buildStatCard('4', 'Incoming', 'Leave Requests', warningColor, Icons.inbox),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildStatCard(
              _approvedCount.toString(),
              'Approved',
              'Leaves',
              successColor,
              Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              _rejectedCount.toString(),
              'Rejected',
              'Leaves',
              lightRed,
              Icons.cancel,
            ),
          ),
if ((_userData['role_id'] ?? 0).toString() == '4') ...[
  const SizedBox(width: 12),
  Expanded(
    child: GestureDetector(
      onTap: () {
        print('Navigating to ViewAllLeavesPage with userData: $_userData');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewAllLeavesPage(userData: _userData),
          ),
        );
      },
      child: _buildStatCard(
        'All',
        'View All',
        'Leave',
        const Color(0xFF9C27B0),
        Icons.visibility,
      ),
    ),
  ),
],


        ],
      ),
    ],
  );
}

  void _showAddMenu(BuildContext context) {
    final empName = _userData['name'] ?? '';
    final designation = _userData['designation'] ?? '';
    final empId = _userData['empId'] ?? '';
    final fla = _userData['fla'] ?? '';
    final sla = _userData['sla'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMenuOption(
                    icon: Icons.event,
                    title: 'Apply Leave',
                    subtitle: 'Request time off',
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddLeavePage(
                            empName: empName,
                            empId: empId,
                            designation: designation,
                            fla: fla,
                            sla: sla,
                            requestType: 'leave',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.directions_walk,
                    title: 'Apply Outdoor Duty',
                    subtitle: 'Request outdoor work assignment',
                    color: lightBlue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OutdoorDutyPage(
                            empName: empName,
                            empId: empId,
                            designation: designation,
                            fla: fla,
                            sla: sla,
                            requestType: 'outdoor',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomNavItem(Icons.add, 'Add', () {
                _showAddMenu(context);
              }),
              _buildBottomNavItem(Icons.home, 'Home', () {}),
              _buildBottomNavItem(Icons.assignment, 'Status', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatusPage(userData: _userData),
                  ),
                );
              }),
              _buildBottomNavItem(Icons.logout, 'Logout', _handleLogout),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String number, String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}