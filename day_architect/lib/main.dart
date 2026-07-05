import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure the database is initialized (tables created, seed data loaded)
  await DatabaseHelper().database;
  runApp(const DayArchitectApp());
}

class DayArchitectApp extends StatelessWidget {
  const DayArchitectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Day Architect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const OnboardingScreen(),
    );
  }
}
