import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Modern Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
      ),
      body: Container(
        color: Colors.black,
        child: Container(
          color: Colors.grey[900],
          child: const DashboardLayout(),
        ),
      ),
    );
  }
}
