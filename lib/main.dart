import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/foreground_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundNotificationService.init();
  // Open the IsolateNameServer port so notification button presses from the
  // task isolate can reach addTaskDataCallback listeners in the UI isolate.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ProviderScope(child: HeartbeatPlanApp()));
}

class HeartbeatPlanApp extends StatelessWidget {
  const HeartbeatPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heartbeat Plan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
