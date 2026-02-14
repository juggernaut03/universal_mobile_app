# Special Note Caching Fix - Implementation Guide

**Date**: February 14, 2026  
**Version**: 4.0.10  
**Issue**: Special instructions from previous orders persisting in new checkout sessions

---

## 📋 Table of Contents
1. [Problem Description](#problem-description)
2. [Root Cause Analysis](#root-cause-analysis)
3. [Solution Overview](#solution-overview)
4. [Implementation Steps](#implementation-steps)
5. [Testing Guide](#testing-guide)
6. [Files Modified](#files-modified)

---

## 🐛 Problem Description

### Issue
When users complete or abandon an order with special instructions (notes), those instructions persist and appear in subsequent checkout sessions. This creates a poor user experience where:
- Old delivery notes appear in new orders
- Users may accidentally submit incorrect instructions
- Checkout data from abandoned sessions carries over

### User Impact
- **Severity**: Medium-High
- **Frequency**: Every checkout session after the first one
- **Affected Users**: All users who use special instructions feature

### Example Scenario
1. User goes to checkout and adds special note: "Leave at door"
2. User completes the order OR abandons checkout
3. User starts a new checkout session
4. ❌ **BUG**: The old note "Leave at door" still appears in the special instructions field

---

## 🔍 Root Cause Analysis

### How Checkout Data Caching Works

The checkout flow uses `SharedPreferences` to cache user selections during the checkout process:

```dart
class CheckoutData {
  DeliveryMethod? deliveryMethod;
  Address? selectedAddress;
  DateTime? deliveryDate;
  String? deliveryTimeSlot;
  String? specialInstructions;  // ← The problematic field
  String? paymentMethod;
  String? pickupName;
  
  // Saves to SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(toJson());
    await prefs.setString('checkout_data', jsonData);
  }
  
  // Loads from SharedPreferences
  static Future<CheckoutData> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('checkout_data');
    if (jsonData != null) {
      return CheckoutData.fromJson(jsonDecode(jsonData));
    }
    return CheckoutData();
  }
  
  // Clears from SharedPreferences
  static Future<void> clearFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkout_data');
  }
}
```

### When Data is Saved

Checkout data is saved in **two places**:

1. **When moving between checkout steps** (Line ~225):
   ```dart
   Future<void> _saveAndProceed() async {
     await _checkoutData.saveToPrefs();
     _goToNextStep();
   }
   ```

2. **Before placing an order** (Line ~3042):
   ```dart
   Future<void> _placeOrder() async {
     // Save instructions
     widget.checkoutData.specialInstructions = _instructionsController.text;
     
     // Save all checkout data
     await widget.checkoutData.saveToPrefs();
     // ... rest of order placement logic
   }
   ```

### When Data is Cleared (Before Fix)

Data was **only** cleared after successful order completion:

1. **After successful online payment** (Line ~3445):
   ```dart
   await ref.read(cartProvider.notifier).clearCart();
   await CheckoutData.clearFromPrefs();
   ```

2. **After successful COD order** (Line ~3473):
   ```dart
   await ref.read(cartProvider.notifier).clearCart();
   await CheckoutData.clearFromPrefs();
   ```

3. **After enhanced payment flow** (enhanced_payment_flow.dart, Line ~649):
   ```dart
   await ref.read(cartProvider.notifier).clearCart();
   await CheckoutData.clearFromPrefs();
   ```

### The Gap

**Problem**: Data is NOT cleared when:
- ❌ User abandons checkout (closes app, navigates away)
- ❌ Payment fails in certain scenarios
- ❌ User navigates back from checkout without completing
- ❌ App crashes during checkout

**Result**: The next checkout session loads the old cached data, including special instructions.

---

## ✅ Solution Overview

### Strategy
Instead of relying on clearing data after order completion, **clear the cached data when ENTERING a new checkout session**. This ensures every checkout starts fresh, regardless of what happened in the previous session.

### Benefits
✅ Guaranteed fresh start for every checkout session  
✅ No dependency on successful order completion  
✅ Handles all edge cases (abandoned checkout, crashes, etc.)  
✅ Simple, single-point fix  
✅ No breaking changes to existing functionality

### Trade-offs
- Users can no longer resume an abandoned checkout session
- This is acceptable because:
  - Cart items are still preserved
  - Re-entering delivery info is quick
  - Fresh data is more reliable than stale cached data

---

## 🛠️ Implementation Steps

### Step 1: Locate the Checkout Flow Screen

Find the file that contains the checkout flow logic. In most apps, this will be:
- `lib/presentation/features/checkout/checkout_flow_screen.dart`

### Step 2: Find the _loadCheckoutData Method

Look for the method that loads checkout data when the screen initializes:

```dart
Future<void> _loadCheckoutData() async {
  setState(() {
    _isLoading = true;
  });

  // Load saved checkout data if any
  _checkoutData = await CheckoutData.loadFromPrefs();

  setState(() {
    _isLoading = false;
  });
}
```

**Location**: Usually around line 180-191

### Step 3: Add clearFromPrefs() Call

Modify the method to clear cached data BEFORE loading:

```dart
Future<void> _loadCheckoutData() async {
  setState(() {
    _isLoading = true;
  });

  // Clear any cached checkout data from previous sessions to ensure fresh start
  // This prevents special notes and other data from persisting across orders
  await CheckoutData.clearFromPrefs();
  
  // Load fresh checkout data (will be empty after clearing)
  _checkoutData = await CheckoutData.loadFromPrefs();

  setState(() {
    _isLoading = false;
  });
}
```

### Step 4: Update Version Number

Update the version in `pubspec.yaml`:

```yaml
# Before
version: 4.0.9+4.0.9

# After
version: 4.0.10+4.0.10
```

### Step 5: Test the Fix

See [Testing Guide](#testing-guide) below.

---

## 🧪 Testing Guide

### Test Case 1: Normal Order Flow
1. Add items to cart
2. Go to checkout
3. Enter special instructions: "Test note 1"
4. Complete the order
5. Start a new checkout session
6. ✅ **Expected**: Special instructions field should be empty

### Test Case 2: Abandoned Checkout
1. Add items to cart
2. Go to checkout
3. Enter special instructions: "Test note 2"
4. Navigate away from checkout (don't complete order)
5. Go back to checkout
6. ✅ **Expected**: Special instructions field should be empty

### Test Case 3: Payment Failure
1. Add items to cart
2. Go to checkout
3. Enter special instructions: "Test note 3"
4. Attempt payment (let it fail or cancel)
5. Start a new checkout session
6. ✅ **Expected**: Special instructions field should be empty

### Test Case 4: App Restart
1. Add items to cart
2. Go to checkout
3. Enter special instructions: "Test note 4"
4. Close the app completely
5. Reopen the app
6. Go to checkout
7. ✅ **Expected**: Special instructions field should be empty

### Test Case 5: Multiple Checkout Attempts
1. Go to checkout, enter "Note 1", abandon
2. Go to checkout again, enter "Note 2", abandon
3. Go to checkout again
4. ✅ **Expected**: Special instructions field should be empty (not "Note 1" or "Note 2")

---

## 📁 Files Modified

### 1. `lib/presentation/features/checkout/checkout_flow_screen.dart`

**Location**: Lines 180-194  
**Change Type**: Modified existing method  
**Lines Changed**: 4 lines added

**Before**:
```dart
Future<void> _loadCheckoutData() async {
  setState(() {
    _isLoading = true;
  });

  // Load saved checkout data if any
  _checkoutData = await CheckoutData.loadFromPrefs();

  setState(() {
    _isLoading = false;
  });
}
```

**After**:
```dart
Future<void> _loadCheckoutData() async {
  setState(() {
    _isLoading = true;
  });

  // Clear any cached checkout data from previous sessions to ensure fresh start
  // This prevents special notes and other data from persisting across orders
  await CheckoutData.clearFromPrefs();
  
  // Load fresh checkout data (will be empty after clearing)
  _checkoutData = await CheckoutData.loadFromPrefs();

  setState(() {
    _isLoading = false;
  });
}
```

### 2. `pubspec.yaml`

**Location**: Line 19  
**Change Type**: Version bump  
**Lines Changed**: 1 line

**Before**:
```yaml
version: 4.0.9+4.0.9
```

**After**:
```yaml
version: 4.0.10+4.0.10
```

---

## 📝 Implementation Checklist

Use this checklist when applying the fix to replica apps:

- [ ] Locate `checkout_flow_screen.dart` file
- [ ] Find the `_loadCheckoutData()` method
- [ ] Add `await CheckoutData.clearFromPrefs();` before loading data
- [ ] Add explanatory comments
- [ ] Update version number in `pubspec.yaml`
- [ ] Run `flutter pub get` if needed
- [ ] Test all 5 test cases
- [ ] Commit changes with descriptive message
- [ ] Push to repository
- [ ] Deploy to production

---

## 🔄 Git Commit Message Template

```
Fix: Clear cached checkout data on session start to prevent special notes persistence

- Fixed issue where special instructions from previous orders were persisting
- Added clearFromPrefs() call at the start of checkout session
- Ensures fresh checkout data for every new order
- Version bump to 4.0.10
```

---

## 📊 Impact Summary

| Metric | Before Fix | After Fix |
|--------|-----------|-----------|
| Special notes persist | ❌ Yes | ✅ No |
| Fresh checkout session | ❌ No | ✅ Yes |
| User confusion | ❌ High | ✅ None |
| Code complexity | Low | Low |
| Performance impact | None | Negligible |

---

## 🎯 Related Issues

This fix also resolves potential issues with:
- Stale delivery addresses persisting
- Old delivery time slots carrying over
- Previous payment method selections remaining
- Pickup names from previous orders appearing

---

## 📞 Support

If you encounter any issues while implementing this fix:
1. Verify the `CheckoutData` class has the `clearFromPrefs()` method
2. Ensure the method is called before `loadFromPrefs()`
3. Check that the checkout screen initializes properly
4. Test with a clean app install if issues persist

---

**Last Updated**: February 14, 2026  
**Implemented By**: Development Team  
**Status**: ✅ Deployed to Production
