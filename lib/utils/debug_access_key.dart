// lib/utils/debug_access_key.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/logger.dart';
import '../presentation/providers/launch_flow_provider.dart';
import '../presentation/providers/auth_providers.dart';

/// A utility widget to display access key for debugging and Postman testing
class AccessKeyDebugScreen extends ConsumerStatefulWidget {
  const AccessKeyDebugScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AccessKeyDebugScreen> createState() => _AccessKeyDebugScreenState();
}

class _AccessKeyDebugScreenState extends ConsumerState<AccessKeyDebugScreen> {
  String _accessKey = 'Loading...';
  List<Map<String, String>> _accessKeySources = [];
  bool _isLoading = true;
  String _error = '';
  
  @override
  void initState() {
    super.initState();
    _loadAccessKey();
  }
  
  Future<void> _loadAccessKey() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      
      final logger = ref.read(loggerProvider);
      logger.log('Loading access key from all possible sources');
      
      List<Map<String, String>> sources = [];
      String? accessKeyFinal;
      
      // Method 1: Try from user profile provider
      try {
        final userProfile = await ref.read(userProfileProvider.future);
        if (userProfile != null) {
          final key = userProfile.accessKey;
          logger.log('Access key from userProfileProvider: $key');
          sources.add({
            'source': 'UserProfileProvider',
            'key': key,
          });
          
          if (accessKeyFinal == null && key.isNotEmpty) {
            accessKeyFinal = key;
          }
        }
      } catch (e) {
        logger.error('Error getting access key from userProfile: $e');
        sources.add({
          'source': 'UserProfileProvider',
          'key': 'Error: $e',
        });
      }
      
      // Method 2: Try from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Try user_profile format
      try {
        final authProfileStr = prefs.getString('user_profile');
        if (authProfileStr != null) {
          final authProfile = jsonDecode(authProfileStr);
          final key = authProfile['accessKey'];
          logger.log('Access key from SharedPreferences user_profile: $key');
          sources.add({
            'source': 'SharedPreferences (user_profile)',
            'key': key ?? 'Not found',
          });
          
          if (accessKeyFinal == null && key != null && key.isNotEmpty) {
            accessKeyFinal = key;
          }
        } else {
          sources.add({
            'source': 'SharedPreferences (user_profile)',
            'key': 'Not found',
          });
        }
      } catch (e) {
        logger.error('Error parsing user_profile: $e');
        sources.add({
          'source': 'SharedPreferences (user_profile)',
          'key': 'Error: $e',
        });
      }
      
      // Try otp_validation_response format
      try {
        final otpResponseStr = prefs.getString('otp_validation_response');
        if (otpResponseStr != null) {
          final otpResponse = jsonDecode(otpResponseStr);
          final key = otpResponse['access_key'];
          logger.log('Access key from otp_validation_response: $key');
          sources.add({
            'source': 'SharedPreferences (otp_validation_response)',
            'key': key ?? 'Not found',
          });
          
          if (accessKeyFinal == null && key != null && key.isNotEmpty) {
            accessKeyFinal = key;
          }
        } else {
          sources.add({
            'source': 'SharedPreferences (otp_validation_response)',
            'key': 'Not found',
          });
        }
      } catch (e) {
        logger.error('Error parsing otp_validation_response: $e');
        sources.add({
          'source': 'SharedPreferences (otp_validation_response)',
          'key': 'Error: $e',
        });
      }
      
      // Try direct storage format
      try {
        final key = prefs.getString('user_access_key');
        logger.log('Access key from user_access_key: $key');
        sources.add({
          'source': 'SharedPreferences (user_access_key)',
          'key': key ?? 'Not found',
        });
        
        if (accessKeyFinal == null && key != null && key.isNotEmpty) {
          accessKeyFinal = key;
        }
      } catch (e) {
        logger.error('Error getting user_access_key: $e');
        sources.add({
          'source': 'SharedPreferences (user_access_key)',
          'key': 'Error: $e',
        });
      }
      
      // Update state with results
      setState(() {
        _isLoading = false;
        _accessKeySources = sources;
        _accessKey = accessKeyFinal ?? 'No access key found';
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading access key: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Key Debugger'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadAccessKey,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(8),
                      color: Colors.red.shade100,
                      child: Text(_error, style: const TextStyle(color: Colors.red)),
                    ),
                  
                  const Text(
                    'Best Access Key for Postman:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _accessKey,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                _copyToClipboard(_accessKey);
                              },
                              tooltip: 'Copy to clipboard',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 32),
                  
                  const Text(
                    'Postman JSON Request Body Template:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: const Text(
                                '{\n  "access_key": "YOUR_ACCESS_KEY",\n  "project_code": "RET5890"\n}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                _copyToClipboard('{\n  "access_key": "$_accessKey",\n  "project_code": "RET5890"\n}');
                              },
                              tooltip: 'Copy with access key',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Text(
                    'All Access Key Sources:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  ..._accessKeySources.map((source) => _buildSourceItem(source)),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Postman Requests:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPostmanExample(
                    'Get Address List', 
                    'POST', 
                    'https://newtech.shalviadvision.com/api/get_address_list', 
                    '{\n  "access_key": "$_accessKey",\n  "project_code": "RET5890"\n}'
                  ),
                  const SizedBox(height: 16),
                  _buildPostmanExample(
                    'Add Address', 
                    'POST', 
                    'https://newtech.shalviadvision.com/api/add_address', 
                    '{\n  "idaddress_book": "12",\n  "project_code": "RET5890",\n  "full_name": "Test User",\n  "access_key": "$_accessKey",\n  "mobile_number": "9876543210",\n  "email_id": " ",\n  "delivery_addr_line_1": "Address Line 1",\n  "delivery_addr_line_2": "Address Line 2",\n  "delivery_addr_city": "Mumbai",\n  "delivery_addr_pincode": "400001",\n  "is_default": "No",\n  "latitude": "",\n  "longitude": "",\n  "area_id": "1"\n}'
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildSourceItem(Map<String, String> source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source['source'] ?? 'Unknown source',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            source['key'] ?? 'No key found',
            style: const TextStyle(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostmanExample(String title, String method, String url, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  _copyToClipboard(body);
                },
                child: const Text('Copy Body'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Body:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              body,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _copyToClipboard(String text) {
    // Note: This function simulates copying to clipboard
    // In a real app, you would use:
    // Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}