import 'package:flutter/material.dart';
import 'screens/alarm_manager_screen.dart';
import 'screens/alarm_screen.dart';
import 'services/places_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize PlacesService
  final placesService = PlacesService();
  await placesService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wake Me Up',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A1A1A), // Midnight color
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A1A),
          primary: const Color(0xFF1A1A1A),
          secondary: const Color(0xFF2196F3), // Material Blue
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AlarmManagerScreen(),
        '/alarm': (context) => const AlarmScreen()
      },
    );
  }
}
