// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leave_management1/main.dart';
import 'package:leave_management1/view/login.dart'; // This contains SEGLMSApp

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    // Load your actual app
    await tester.pumpWidget(const SEGLMSApp());

    // Check if the login screen is shown initially
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
