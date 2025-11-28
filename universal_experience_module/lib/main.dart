import 'package:flutter/material.dart';
import 'universal_experience_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniversalExperiencePreviewApp());
}

class UniversalExperiencePreviewApp extends StatelessWidget {
  const UniversalExperiencePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Experience SDK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: UniversalExperienceScreen(
        hostAppName: 'Module Demo',
        userId: 'user_123',
        sessionId: 'session_abc',
        referenceId: 'ref-demo-001',
        cameraPermissionGranted: true, // preview app: assume granted
        locationPermissionGranted: true,
        onEvent: (event) {
          debugPrint(
              '[KYC EVENT] type=${event.type} step=${event.step} msg=${event.message} meta=${event.meta}');
        },
      ),
    );
  }
}
