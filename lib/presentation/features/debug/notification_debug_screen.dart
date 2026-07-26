import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../di/service_providers.dart';

class NotificationDebugScreen extends ConsumerStatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  ConsumerState<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends ConsumerState<NotificationDebugScreen> {
  String _fcmToken = 'Loading...';
  String _debugReport = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFCMToken();
  }

  Future<void> _loadFCMToken() async {
    try {
      final notificationService = ref.read(firebaseNotificationServiceProvider);
      final token = await notificationService.getCurrentToken();
      setState(() {
        _fcmToken = token ?? 'Failed to get token';
      });
    } catch (e) {
      setState(() {
        _fcmToken = 'Error: $e';
      });
    }
  }

  Future<void> _testLocalNotification() async {
    setState(() => _isLoading = true);
    try {
      // You can add a test method to the service or create a test notification here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification triggered')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateDebugReport() async {
    setState(() => _isLoading = true);
    try {
      final report = StringBuffer();
      report.writeln('=== NOTIFICATION DEBUG REPORT ===');
      report.writeln('Generated: ${DateTime.now()}');
      report.writeln();
      
      // FCM Token
      final notificationService = ref.read(firebaseNotificationServiceProvider);
      final token = await notificationService.getCurrentToken();
      report.writeln('FCM Token: ${token ?? "NULL"}');
      
      // SharedPreferences token
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');
      report.writeln('Saved Token: ${savedToken ?? "NULL"}');
      
      setState(() {
        _debugReport = report.toString();
      });
    } catch (e) {
      setState(() {
        _debugReport = 'Error generating report: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: _fcmToken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FCM Token Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'FCM Token',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _copyToken,
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy Token',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fcmToken,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use this token to send test messages from Firebase Console',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Actions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Test Actions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testLocalNotification,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Test Local Notification'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateDebugReport,
                        icon: const Icon(Icons.assessment),
                        label: const Text('Generate Debug Report'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadFCMToken,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Token'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Debug Report Section
            if (_debugReport.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Debug Report',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _debugReport,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Instructions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Testing Instructions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Copy the FCM token above\n'
                      '2. Go to Firebase Console > Cloud Messaging\n'
                      '3. Click "Send your first message"\n'
                      '4. Enter notification title and body\n'
                      '5. Click "Send test message"\n'
                      '6. Paste your FCM token\n'
                      '7. Click "Test"\n\n'
                      'Expected behavior:\n'
                      '• App in foreground: Local notification shows\n'
                      '• App in background: System notification shows\n'
                      '• App terminated: System notification shows\n'
                      '• Tap notification: App opens and navigates',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
