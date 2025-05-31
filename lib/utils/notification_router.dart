// import '';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class NotificationRouter {
//   // Define which URLs are accessible to which roles
//   static final Map<String, Set<String>> roleUrlAccess = {
//     'teacher': {
//       // 'attendance_status',
//       // 'notice',
//       // 'gallery',
//       // 'quiz',
//       // 'custom',
//       // 'fees',
//       // 'timetable',
//     },
//     'student': {
//       // 'attendance_status', 'notice', 'gallery', 'timetable'
//     },
//   };

//   // Define the route builders for each role and URL
//   static final Map<String, Map<String, Widget Function(BuildContext)>>
//   routeBuilders = {
//     'teacher': {
//       // 'attendance_status': (_) => TeacherDashboard(),
//       // 'notice': (_) => NoticePage(),
//       // 'gallery': (_) => StudentGallery(),
//       // 'quiz': (_) => QuizAssignment(),
//       // 'custom': (_) => TeacherDashboard(),
//       // 'fees': (_) => StudentFees(),
//       // 'timetable': (_) => TeacherTimetableView(),
//     },
//     'student': {
//       // 'attendance_status': (_) => AttendanceScreen(),
//       // 'notice': (_) => NoticePage(),
//       // 'gallery': (_) => StudentGallery(),
//       // 'timetable': (_) => StudentTimetable(),
//       // 'custom': (_) => StudentDashboard(),
//     },
//   };

//   // Get the current user role
//   static Future<String> _getUserRole() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString('role') ??
//         'student'; // Default to student if not set
//   }

//   // Check if the user has permission for this URL
//   static bool _hasPermission(String userRole, String url) {
//     return roleUrlAccess.containsKey(userRole) &&
//         roleUrlAccess[userRole]!.contains(url);
//   }

//   // Navigate to the appropriate screen based on URL and role
//   static Future<void> navigateToRoute(String url) async {
//     if (url.isEmpty) {
//       print("Empty URL provided");
//       return;
//     }

//     final userRole = await _getUserRole();
//     print("Current user session type: $userRole");

//     // Check permission
//     if (!_hasPermission(userRole, url)) {
//       print(
//         "Access denied: User with role '$userRole' doesn't have permission for URL '$url'",
//       );
//       return;
//     }

//     try {
//       // Get builder function for this route
//       final routeBuilder = routeBuilders[userRole]?[url];
//       if (routeBuilder != null) {
//         print("Navigating to $url for $userRole");
//         navigatorKey.currentState?.pushReplacement(
//           MaterialPageRoute(builder: routeBuilder),
//         );
//       } else {
//         print("No route builder found for $url with role $userRole");
//       }
//     } catch (e) {
//       print("Navigation error: $e");
//       // Fallback to dashboard on error
//       navigatorKey.currentState?.pushReplacement(
//         MaterialPageRoute(
//           builder: (_) => userRole == 'teacher' ? MyApp() : MyApp(),
//         ),
//       );
//     }
//   }
// }
