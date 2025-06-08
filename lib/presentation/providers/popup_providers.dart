import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/popup_service.dart';
import '../../data/models/popup_model.dart';
import 'launch_flow_provider.dart';

// Service provider
final popupServiceProvider = Provider<PopupService>((ref) {
  final logger = ref.watch(loggerProvider);
  return PopupService(logger: logger);
});

// Popup data provider
final popupDataProvider = FutureProvider.family<PopupResponse?, String>((ref, storeCode) async {
  if (storeCode.isEmpty) return null;
  
  final service = ref.read(popupServiceProvider);
  return await service.getPopupScreen(storeCode);
});

// Provider to track popup display state
final popupDisplayStateProvider = StateNotifierProvider<PopupDisplayStateNotifier, PopupDisplayState>((ref) {
  return PopupDisplayStateNotifier();
});

class PopupDisplayState {
  final bool isVisible;
  final bool hasBeenShown;
  final DateTime? lastShownDate;
  final String? currentStoreCode;
  final bool isInitialized;
  final String? currentSessionId;

  const PopupDisplayState({
    this.isVisible = false,
    this.hasBeenShown = false,
    this.lastShownDate,
    this.currentStoreCode,
    this.isInitialized = false,
    this.currentSessionId,
  });

  PopupDisplayState copyWith({
    bool? isVisible,
    bool? hasBeenShown,
    DateTime? lastShownDate,
    String? currentStoreCode,
    bool? isInitialized,
    String? currentSessionId,
  }) {
    return PopupDisplayState(
      isVisible: isVisible ?? this.isVisible,
      hasBeenShown: hasBeenShown ?? this.hasBeenShown,
      lastShownDate: lastShownDate ?? this.lastShownDate,
      currentStoreCode: currentStoreCode ?? this.currentStoreCode,
      isInitialized: isInitialized ?? this.isInitialized,
      currentSessionId: currentSessionId ?? this.currentSessionId,
    );
  }
}

class PopupDisplayStateNotifier extends StateNotifier<PopupDisplayState> {
  PopupDisplayStateNotifier() : super(const PopupDisplayState());

  static const String _keyLastShown = 'popup_last_shown';
  static const String _keySessionId = 'popup_session_id';

  Future<void> initializePopupState(String storeCode) async {
    if (state.isInitialized && state.currentStoreCode == storeCode) {
      return; // Already initialized for this store
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final lastSessionId = prefs.getString('${_keySessionId}_$storeCode');
      
      // Always show popup on new app launch (different session)
      final shouldShow = _shouldShowPopupOnLaunch(lastSessionId, currentSessionId);
      
      state = state.copyWith(
        currentStoreCode: storeCode,
        currentSessionId: currentSessionId,
        hasBeenShown: !shouldShow,
        isInitialized: true,
      );
      
      // Store current session ID
      await prefs.setString('${_keySessionId}_$storeCode', currentSessionId);
      
      // Show popup immediately if it should be shown
      if (shouldShow) {
        Future.delayed(const Duration(milliseconds: 100), () {
          showPopup();
        });
      }
      
    } catch (e) {
      // If SharedPreferences fails, assume popup should be shown
      state = state.copyWith(
        currentStoreCode: storeCode,
        currentSessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        hasBeenShown: false,
        isInitialized: true,
      );
      
      // Show popup immediately
      Future.delayed(const Duration(milliseconds: 100), () {
        showPopup();
      });
    }
  }

  /// This method ensures popup shows on every app launch
  /// by comparing session IDs instead of dates
  bool _shouldShowPopupOnLaunch(String? lastSessionId, String currentSessionId) {
    // If no previous session ID exists, show popup
    if (lastSessionId == null || lastSessionId.isEmpty) return true;
    
    // If session IDs are different, it's a new app launch
    return lastSessionId != currentSessionId;
  }

  Future<void> showPopup() async {
    if (state.isInitialized && !state.hasBeenShown && 
        state.currentStoreCode != null && !state.isVisible) {
      // Show popup immediately without delay
      state = state.copyWith(isVisible: true);
    }
  }

  Future<void> hidePopup() async {
    if (state.isVisible && state.currentStoreCode != null) {
      try {
        // Mark as shown for this session only
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '${_keyLastShown}_${state.currentStoreCode}',
          DateTime.now().toIso8601String(),
        );
      } catch (e) {
        // Continue even if storage fails
      }
      
      state = state.copyWith(
        isVisible: false,
        hasBeenShown: true,
        lastShownDate: DateTime.now(),
      );
    }
  }

  void resetForNewStore(String storeCode) {
    state = PopupDisplayState(
      currentStoreCode: storeCode,
      isInitialized: false,
    );
  }

  /// Force show popup (useful for testing or manual trigger)
  Future<void> forceShowPopup() async {
    if (state.currentStoreCode != null) {
      state = state.copyWith(
        hasBeenShown: false,
        isVisible: false,
      );
      // Trigger the normal show process
      await showPopup();
    }
  }

  /// Reset popup state for new app session
  /// Call this when app comes to foreground from background
  Future<void> resetForNewSession() async {
    if (state.currentStoreCode != null) {
      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_keySessionId}_${state.currentStoreCode}', newSessionId);
        
        state = state.copyWith(
          currentSessionId: newSessionId,
          hasBeenShown: false,
          isVisible: false,
        );
      } catch (e) {
        // Fallback: just reset the session state
        state = state.copyWith(
          currentSessionId: newSessionId,
          hasBeenShown: false,
          isVisible: false,
        );
      }
    }
  }
}