import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure the database is initialized (tables created, seed data loaded)
  await DatabaseHelper().database;
  // Initialize local notifications
  await NotificationService().init();
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
      builder: (context, child) {
        // Respect system accessibility text scaling
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Cap text scaling at 1.3x to avoid layout breakage while still
            // respecting user accessibility preferences
            textScaler: TextScaler.linear(scale.clamp(0.8, 1.3)),
          ),
          child: child!,
        );
      },
      home: const OnboardingScreen(),
    );
  }
}
