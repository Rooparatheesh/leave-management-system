import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:leave_management1/view/forgot_password.dart';
import 'package:leave_management1/view/login.dart';
import 'package:leave_management1/view/profile_page.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Background message handler (register before runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request permission (iOS)
  try {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');
  } catch (e) {
    print('Permission request error: $e');
  }

  // Retrieve and store FCM token
  await _saveFcmToken();

  runApp(const SEGLMSApp());
}

// Function to get and store FCM token
Future<void> _saveFcmToken() async {
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $fcmToken');

    if (fcmToken != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcmToken', fcmToken);
      print('FCM token saved to SharedPreferences');
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcmToken', newToken);
      print('FCM token refreshed: $newToken');
      // optionally send newToken to your backend / update via API
    });
  } catch (e) {
    print('Error saving FCM token: $e');
  }
}

class SEGLMSApp extends StatefulWidget {
  const SEGLMSApp({super.key});

  @override
  State<SEGLMSApp> createState() => _SEGLMSAppState();
}

class _SEGLMSAppState extends State<SEGLMSApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('onMessage: ${message.messageId}');
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? '';
        final body = notification.body ?? '';
        // show simple alert dialog if possible
        final ctx = navigatorKey.currentState?.context;
        if (ctx != null) {
          showDialog(
            context: ctx,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });

    // When the app is opened from a notification (background / not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('onMessageOpenedApp: ${message.messageId}, data: ${message.data}');
      // navigate or handle deep link; example: open incoming leaves screen
      // navigatorKey.currentState?.pushNamed('/incoming-leaves');
    });

    // If the app was terminated and opened from a notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('getInitialMessage: ${message.messageId}, data: ${message.data}');
        // handle initial message if needed
      }
    });
  }

  Future<Map<String, dynamic>?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) return null;

    // Try parsing stored userData JSON (this is what your login saved)
    final userDataStr = prefs.getString('userData');
    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(userDataStr);
        return {
          'empId': parsed['empId']?.toString() ?? '',
          'name': parsed['name']?.toString() ?? '',
          'designation': parsed['designation']?.toString() ?? '',
          'fla': parsed['fla']?.toString() ?? '',
          'sla': parsed['sla']?.toString() ?? '',
          'role_id': parsed['role_id']?.toString() ?? '',
        };
      } catch (e) {
        print('Error parsing userData from prefs: $e');
      }
    }

    // fallback: older style individual keys (if you saved separately elsewhere)
    final employeeId = prefs.getString('empId');
    final name = prefs.getString('name');

    if (employeeId != null && name != null) {
      return {
        'empId': employeeId,
        'name': name,
        'designation': prefs.getString('designation') ?? '',
        'fla': prefs.getString('fla') ?? '',
        'sla': prefs.getString('sla') ?? '',
        'role_id': prefs.getString('roleId') ?? '',
      };
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SEG LMS/OD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: getLoggedInUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data != null) {
            return ProfilePage(userData: snapshot.data!);
          } else {
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/profile': (context) => ProfilePage(
              userData:
                  ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
            ),
        // add other named routes if needed, e.g. '/incoming-leaves'
      },
    );
  }
}
