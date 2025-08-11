import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  debugPrint('DEBUG: Main function started');
  
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DEBUG: WidgetsFlutterBinding ensured');

  runApp(const DebugApp());
  debugPrint('DEBUG: runApp called');
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('DEBUG: DebugApp build() called');
    
    return MaterialApp(
      title: 'Debug Modern Dashboard',
      theme: ThemeData.dark(),
      home: const DebugScreen(),
    );
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String status = 'App loaded successfully!';
  
  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG: DebugScreen initState() called');
    _testFirebaseInit();
  }

  Future<void> _testFirebaseInit() async {
    try {
      debugPrint('DEBUG: Testing Firebase initialization...');
      
      // Test basic Firebase imports
      setState(() {
        status = 'Testing Firebase initialization...';
      });
      
      // Try to import Firebase
      if (kIsWeb) {
        debugPrint('DEBUG: Running on web platform');
        setState(() {
          status = 'Web platform detected. Firebase SDK should be loaded.';
        });
      } else {
        debugPrint('DEBUG: Running on native platform');
        setState(() {
          status = 'Native platform detected.';
        });
      }
      
    } catch (e) {
      debugPrint('DEBUG: Error during Firebase test: $e');
      setState(() {
        status = 'Error during Firebase test: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('DEBUG: DebugScreen build() called');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Debug Modern Dashboard'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Debug Mode Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  debugPrint('DEBUG: Test button pressed');
                  setState(() {
                    status = 'Button pressed at ${DateTime.now()}';
                  });
                },
                child: const Text('Test Button'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}