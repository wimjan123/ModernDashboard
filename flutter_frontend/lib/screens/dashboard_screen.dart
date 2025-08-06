import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';
import '../services/ffi_bridge.dart';
import '../services/cpp_bridge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _ffiStatus = 'Engine initialized at startup';
  String _newsPreview = '(no data)';

  @override
  void initState() {
    super.initState();
    // Attempt to load initial news on startup
    _loadNews();
  }

  void _loadNews() {
    try {
      String data;
      if (FfiBridge.isSupported) {
        data = FfiBridge.getNewsData();
      } else {
        data = CppBridge.getNewsData();
      }
      setState(() {
        _newsPreview = data.length > 200 ? '${data.substring(0, 200)}…' : data;
      });
    } catch (e) {
      // Fallback to mock data
      try {
        final data = CppBridge.getNewsData();
        setState(() {
          _newsPreview = data.length > 200 ? '${data.substring(0, 200)}…' : data;
        });
      } catch (fallbackError) {
        setState(() {
          _newsPreview = 'Load error: $e (Fallback also failed: $fallbackError)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFFISupported = FfiBridge.isSupported;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Modern Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            // Simple test content to verify the app is working
            Container(
              height: 100,
              color: Colors.blue,
              child: const Center(
                child: Text(
                  'DASHBOARD TEST - IF YOU SEE THIS, THE APP IS WORKING',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Existing dashboard content
            Expanded(
              child: Container(
                color: Colors.grey[900],
                child: const DashboardLayout(),
              ),
            ),
            // FFI test panel
            Container(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FFI Supported: $isFFISupported', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Status: $_ffiStatus', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: _loadNews,
                          child: const Text('Get News'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('News Preview:', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[700],
                      ),
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Text(
                          _newsPreview,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
