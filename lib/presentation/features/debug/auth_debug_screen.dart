// lib/presentation/features/debug/auth_debug_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../../di/infrastructure_providers.dart';

class AuthDebugScreen extends ConsumerWidget {
  const AuthDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Debug'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authentication State Debug',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Reactive login status
            Consumer(
              builder: (context, ref, child) {
                final isLoggedInReactive = ref.watch(isLoggedInReactiveProvider);
                return Card(
                  child: ListTile(
                    title: const Text('Reactive Login Status'),
                    subtitle: Text('Status: $isLoggedInReactive'),
                    trailing: Icon(
                      isLoggedInReactive ? Icons.check_circle : Icons.cancel,
                      color: isLoggedInReactive ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
            
            // Async login status
            Consumer(
              builder: (context, ref, child) {
                final isLoggedInAsync = ref.watch(isLoggedInProvider);
                return Card(
                  child: ListTile(
                    title: const Text('Async Login Status'),
                    subtitle: Text('Status: ${isLoggedInAsync.valueOrNull}'),
                    trailing: isLoggedInAsync.when(
                      data: (isLoggedIn) => Icon(
                        isLoggedIn ? Icons.check_circle : Icons.cancel,
                        color: isLoggedIn ? Colors.green : Colors.red,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, _) => const Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
            
            // User profile stream
            Consumer(
              builder: (context, ref, child) {
                final userProfileStream = ref.watch(userProfileStreamProvider);
                return Card(
                  child: ListTile(
                    title: const Text('User Profile Stream'),
                    subtitle: userProfileStream.when(
                      data: (profile) => Text(
                        profile != null 
                          ? 'Mobile: ${profile.mobile}\nAccess Key: ${profile.accessKey.substring(0, 8)}...'
                          : 'No profile'
                      ),
                      loading: () => const Text('Loading...'),
                      error: (error, _) => Text('Error: $error'),
                    ),
                  ),
                );
              },
            ),
            
            // Login status stream  
            Consumer(
              builder: (context, ref, child) {
                final loginStatusStream = ref.watch(loginStatusStreamProvider);
                return Card(
                  child: ListTile(
                    title: const Text('Login Status Stream'),
                    subtitle: loginStatusStream.when(
                      data: (status) => Text('Status: $status'),
                      loading: () => const Text('Loading...'),
                      error: (error, _) => Text('Error: $error'),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Refresh buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.invalidate(isLoggedInProvider);
                      ref.invalidate(userProfileProvider);
                    },
                    child: const Text('Refresh Auth State'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final authManager = ref.read(centralizedAuthManagerProvider);
                      await authManager.refreshValidation();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Auth validation refreshed')),
                      );
                    },
                    child: const Text('Force Refresh'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Test logout
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final logout = ref.read(logoutProvider);
                await logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out')),
                );
              },
              child: const Text('Test Logout'),
            ),
          ],
        ),
      ),
    );
  }
}