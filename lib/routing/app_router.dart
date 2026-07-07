import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/auth/presentation/screens/biometric_enrollment_screen.dart';
import '../features/auth/presentation/screens/kyc_verification_screen.dart';
import '../features/auth/presentation/screens/device_management_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/patient/presentation/screens/patient_dashboard_screen.dart';
import '../features/patient/presentation/screens/patient_shell_screen.dart';
import '../features/patient/presentation/screens/add_prescription_screen.dart';
import '../features/patient/presentation/screens/prescriptions_screen.dart';
import '../features/patient/presentation/screens/qr_code_screen.dart';
import '../features/patient/presentation/screens/medical_history_screen.dart';
import '../features/patient/presentation/screens/privacy_settings_screen.dart';
import '../features/doctor/presentation/screens/doctor_dashboard_screen.dart';
import '../features/doctor/presentation/screens/patient_lookup_screen.dart';
import '../features/doctor/presentation/screens/patient_record_screen.dart';
import '../features/doctor/presentation/screens/prescription_history_screen.dart';
import '../features/doctor/presentation/screens/new_prescription_screen.dart';
import '../features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart';
import '../features/pharmacist/presentation/screens/dispensing_history_screen.dart';
import '../features/pharmacist/presentation/screens/dispense_screen.dart';
import '../features/pharmacist/presentation/screens/pharmacist_search_screen.dart';
import '../features/emergency/presentation/screens/patient_emergency_screen.dart';
import '../features/emergency/presentation/screens/qr_scanner_screen.dart';
import '../features/emergency/presentation/screens/emergency_data_screen.dart';
import '../features/emergency/presentation/screens/emergency_access_history_screen.dart';
import '../features/patient/presentation/screens/vitals_history_screen.dart';
import '../features/patient/presentation/screens/book_appointment_screen.dart';
import '../features/shared/presentation/screens/chat_list_screen.dart';
import '../features/shared/presentation/screens/chat_room_screen.dart';
import '../features/doctor/presentation/screens/manage_availability_screen.dart';
import '../features/shared/presentation/screens/splash_screen.dart';
import '../features/shared/presentation/screens/profile_screen.dart';
import '../features/shared/presentation/screens/notifications_screen.dart';
import '../features/shared/models/user_profile.dart';
import 'route_names.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(currentProfileProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.read(routerNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final profileAsync = ref.read(currentProfileProvider);
      final profile = profileAsync.valueOrNull;
      final isAuthenticated = authState.valueOrNull != null;

      final isAuthRoute = state.matchedLocation == RouteNames.signIn ||
          state.matchedLocation == RouteNames.signUp ||
          state.matchedLocation == RouteNames.roleSelection;
      final isSplash = state.matchedLocation == RouteNames.splash;

      // If still loading, stay on splash
      if (authState.isLoading && isSplash) {
        return null;
      }

      // Not authenticated - redirect to role selection (unless already on auth route)
      if (!isAuthenticated && !isAuthRoute && !isSplash) {
        // Allow KYC and device management screens without auth
        final isKYCRoute = state.matchedLocation == RouteNames.kycVerification;
        final isDeviceRoute = state.matchedLocation == RouteNames.deviceManagement;

        if (!isKYCRoute && !isDeviceRoute) {
          return RouteNames.roleSelection;
        }
      }

      // Authenticated but on auth route - redirect to appropriate dashboard
      if (isAuthenticated && isAuthRoute) {
        if (profile == null) {
          return null; // wait for profile to load
        }
        return _getDashboardRoute(profile);
      }

      // Enforce role-specific paths
      if (isAuthenticated && profile != null) {
        final path = state.matchedLocation;
        final expectedPrefix = _rolePrefix(profile.role);
        final isCommonRoute = path == RouteNames.profile ||
            path == RouteNames.notifications ||
            path == RouteNames.biometricEnrollment ||
            path == RouteNames.kycVerification ||
            path == RouteNames.deviceManagement ||
            path == '/chat-list' ||
            path.startsWith('/chat/');

        if (!isCommonRoute &&
            expectedPrefix != null &&
            !path.startsWith(expectedPrefix)) {
          return _getDashboardRoute(profile);
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: RouteNames.roleSelection,
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.signIn,
        name: 'signIn',
        builder: (context, state) {
          final role = state.extra as String? ?? 'patient';
          return SignInScreen(role: role);
        },
      ),
      GoRoute(
        path: RouteNames.signUp,
        name: 'signUp',
        builder: (context, state) {
          final role = state.extra as String? ?? 'patient';
          return SignUpScreen(role: role);
        },
      ),
      GoRoute(
        path: RouteNames.biometricEnrollment,
        name: 'biometricEnrollment',
        builder: (context, state) {
          final isMandatory = state.extra as bool? ?? false;
          return BiometricEnrollmentScreen(isMandatory: isMandatory);
        },
      ),
      GoRoute(
        path: RouteNames.kycVerification,
        name: 'kycVerification',
        builder: (context, state) => const KYCVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.deviceManagement,
        name: 'deviceManagement',
        builder: (context, state) => const DeviceManagementScreen(),
      ),

      // Common Routes (shared across all roles)
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Chat routes — shared across patient, doctor, pharmacist
      GoRoute(
        path: '/chat-list',
        name: 'chatList',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        name: 'chatRoom',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final otherName = state.extra as String? ?? 'Secure Chat';
          return ChatRoomScreen(roomId: roomId, otherName: otherName);
        },
      ),

      // ── Patient Shell (persistent floating nav bar across 4 main tabs) ──
      ShellRoute(
        builder: (context, state, child) => PatientShellScreen(child: child),
        routes: [
          // Tab 0 – Home
          GoRoute(
            path: RouteNames.patientDashboard,
            name: 'patientDashboard',
            builder: (context, state) => const PatientDashboardScreen(),
          ),
          // Tab 1 – Records
          GoRoute(
            path: RouteNames.patientMedicalHistory,
            name: 'patientMedicalHistory',
            builder: (context, state) => const MedicalHistoryScreen(),
          ),
          // Tab 2 – Profile (patient shell tab)
          GoRoute(
            path: RouteNames.patientProfile,
            name: 'patientProfileShell',
            builder: (context, state) => const ProfileScreen(),
          ),
          // Tab 3 – Emergency
          GoRoute(
            path: RouteNames.patientEmergency,
            name: 'patientEmergency',
            builder: (context, state) => const PatientEmergencyScreen(),
          ),
        ],
      ),

      // Patient sub-routes (pushed on top, no nav bar — intentional)
      GoRoute(
        path: RouteNames.patientPrescriptions,
        name: 'patientPrescriptions',
        builder: (context, state) => const PrescriptionsScreen(),
      ),
      GoRoute(
        path: RouteNames.patientNewPrescription,
        name: 'patientNewPrescription',
        builder: (context, state) => const AddPrescriptionScreen(),
      ),
      GoRoute(
        path: RouteNames.patientQrCode,
        name: 'patientQrCode',
        builder: (context, state) => const QrCodeScreen(),
      ),
      GoRoute(
        path: '/patient/vitals-history',
        name: 'patientVitalsHistory',
        builder: (context, state) => const VitalsHistoryScreen(),
      ),
      GoRoute(
        path: '/patient/book-appointment',
        name: 'patientBookAppointment',
        builder: (context, state) => const BookAppointmentScreen(),
      ),
      GoRoute(
        path: RouteNames.patientPrivacy,
        name: 'patientPrivacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/patient/add-prescription',
        name: 'patientAddPrescription',
        builder: (context, state) => const AddPrescriptionScreen(),
      ),


      // Doctor Routes
      GoRoute(
        path: RouteNames.doctorDashboard,
        name: 'doctorDashboard',
        builder: (context, state) => const DoctorDashboardScreen(),
      ),
      GoRoute(
        path: '/doctor/availability',
        name: 'doctorAvailability',
        builder: (context, state) => const ManageAvailabilityScreen(),
      ),
      GoRoute(
        path: RouteNames.doctorPatientLookup,
        name: 'doctorPatientLookup',
        builder: (context, state) => const PatientLookupScreen(),
      ),
      GoRoute(
        path: RouteNames.doctorPatientRecord,
        name: 'doctorPatientRecord',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          final patientId = extras?['patientId'] as String? ?? '';
          final patientName = extras?['patientName'] as String? ?? '';
          return PatientRecordScreen(patientId: patientId, patientName: patientName);
        },
      ),
      GoRoute(
        path: RouteNames.doctorNewPrescription,
        name: 'doctorNewPrescription',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return NewPrescriptionScreen(
            patientId: extras?['patientId'] ?? '',
            patientName: extras?['patientName'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RouteNames.doctorHistory,
        name: 'doctorHistory',
        builder: (context, state) => const PrescriptionHistoryScreen(),
      ),

      // Pharmacist Routes
      GoRoute(
        path: RouteNames.pharmacistDashboard,
        name: 'pharmacistDashboard',
        builder: (context, state) => const PharmacistDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.pharmacistDispense,
        name: 'pharmacistDispense',
        builder: (context, state) {
          final qrCodeId = state.extra as String?;
          return DispenseScreen(initialQrCodeId: qrCodeId);
        },
      ),
      GoRoute(
        path: RouteNames.pharmacistHistory,
        name: 'pharmacistHistory',
        builder: (context, state) => const DispensingHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.pharmacistSearch,
        name: 'pharmacistSearch',
        builder: (context, state) => const PharmacistSearchScreen(),
      ),

      // Patient Emergency sub-routes (pushed on top — no nav bar)
      GoRoute(
        path: RouteNames.patientEmergencyScan,
        name: 'patientEmergencyScan',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '${RouteNames.patientEmergencyView}/:qrCodeId',
        name: 'patientEmergencyView',
        builder: (context, state) {
          final qrCodeId = state.pathParameters['qrCodeId']!;
          return EmergencyDataScreen(qrCodeId: qrCodeId);
        },
      ),
      GoRoute(
        path: RouteNames.patientEmergencyAudit,
        name: 'patientEmergencyAudit',
        builder: (context, state) => const EmergencyAccessHistoryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

String _getDashboardRoute(UserProfile? profile) {
  switch (profile?.role) {
    case 'doctor':
      return RouteNames.doctorDashboard;
    case 'pharmacist':
      return RouteNames.pharmacistDashboard;
    case 'patient':
    default:
      return RouteNames.patientDashboard;
  }
}


String? _rolePrefix(String role) {
  switch (role) {
    case 'doctor':
      return '/doctor';
    case 'pharmacist':
      return '/pharmacist';
    case 'patient':
      return '/patient';
    default:
      return null;
  }
}