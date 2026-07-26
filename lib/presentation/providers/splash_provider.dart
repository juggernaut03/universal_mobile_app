// lib/presentation/providers/splash_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../di/service_providers.dart';
import '../../di/infrastructure_providers.dart';

// Google Maps Service provider

// Provider to track Google Maps initialization status
final googleMapsInitializedProvider = StateProvider<bool>((ref) => false);

// Provider to track if splash screen has completed
final splashCompletedProvider = StateProvider<bool>((ref) => false);

/// Handles initialization tasks during splash screen display
final splashInitializationProvider = FutureProvider<void>((ref) async {
  final logger = ref.watch(loggerProvider);
  
  logger.log('Starting app initialization');
  
  // Initialize Google Maps API
  try {
    logger.log('Initializing Google Maps API');
    final googleMapsService = ref.read(googleMapsServiceProvider);
    final isInitialized = await googleMapsService.initialize();
    
    // Update the initialization status
    ref.read(googleMapsInitializedProvider.notifier).state = isInitialized;
    
    if (isInitialized) {
      logger.log('Google Maps API initialized successfully');
    } else {
      logger.error('Failed to initialize Google Maps API, will use fallback mechanisms');
    }
  } catch (e) {
    logger.error('Error initializing Google Maps API: $e');
    // Don't prevent app from starting if Google Maps fails
  }
  
  // Simulate other initialization tasks if needed
  await Future.delayed(const Duration(milliseconds: 2000));
  
  logger.log('App initialization completed');
  return;
});