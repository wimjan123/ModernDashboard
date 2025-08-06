import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';
import '../services/ffi_bridge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _ffiStatus = 'Engine not initialized';
  String _newsPreview = '(no data)';

  void _initEngine() {
    try {
      final ok = FfiBridge.initializeEngine();
      setState(() {
        _ffiStatus = ok ? 'Engine initialized' : 'Engine failed to initialize';
      });
    } catch (e) {
      setState(() {
        _ffiStatus = 'Init error: $e';
      });
    }
  }

  void _loadNews() {
    try {
      final data = FfiBridge.getNewsData();
      setState(() {
        _newsPreview = data.length > 200 ? '${data.substring(0, 200)}…' : data;
      });
    } catch (e) {
      setState(() {
        _newsPreview = 'Load error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFFISupported = FfiBridge.isSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modern Dashboard'),
      ),
      body: Column(
        children: [
          // Existing dashboard content
          const Expanded(child: DashboardLayout()),
          // FFI test panel
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FFI Supported: $isFFISupported'),
                const SizedBox(height: 8),
                Text('Status: $_ffiStatus'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: isFFISupported ? _initEngine : null,
                      child: const Text('Initialize Engine (FFI)'),
                    ),
                    ElevatedButton(
                      onPressed: isFFISupported ? _loadNews : null,
                      child: const Text('Get News (FFI)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('News Preview:'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Text(
                      _newsPreview,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
