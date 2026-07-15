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
import '../features/patient/providers/patient_provider.dart';
import '../features/auth/presentation/screens/two_factor_verification_screen.dart';
import '../services/two_factor_service.dart';
import '../services/supabase_service.dart';
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
import '../features/doctor/presentation/screens/manage_availability_screen.dart';
import '../features/shared/presentation/screens/splash_screen.dart';
import '../features/shared/presentation/screens/profile_screen.dart';
import '../features/shared/presentation/screens/notifications_screen.dart';
import '../features/shared/models/user_profile.dart';
import 'route_names.dart';
import '../core/logging/app_logger.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(currentProfileProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(isDeviceRegisteredProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(isKycVerifiedProvider, (previous, next) {
      notifyListeners();
    });
    _ref.listen(isBiometricEnrolledProvider, (previous, next) {
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
      // NOTE: Use ref.read() here — redirect is NOT a widget build method.
      // Reactive re-evaluation is handled by RouterNotifier (refreshListenable),
      // which listens to all relevant providers and calls notifyListeners().
      final authState = ref.read(authStateProvider);
      final profileAsync = ref.read(currentProfileProvider);
      final profile = profileAsync.valueOrNull;
      final isAuthenticated = SupabaseService.instance.isAuthenticated;

      final isDeviceRegisteredAsync = ref.read(isDeviceRegisteredProvider);
      final isKycVerifiedAsync = ref.read(isKycVerifiedProvider);
      final isBiometricEnrolledAsync = ref.read(isBiometricEnrolledProvider);

      final isAuthRoute =
          state.matchedLocation == RouteNames.signIn ||
          state.matchedLocation == RouteNames.signUp ||
          state.matchedLocation == RouteNames.roleSelection;
      final isSplash = state.matchedLocation == RouteNames.splash;

      // If auth state is still loading, stay on splash
      if (authState.isLoading && isSplash) {
        return null;
      }

      // Not authenticated — if on splash, let SplashScreen handle navigation.
      // If on any other protected route, send to role selection.
      if (!isAuthenticated) {
        if (isSplash) {
          return null; // SplashScreen._checkAuthAndNavigate() takes over
        }
        if (!isAuthRoute) {
          return RouteNames.roleSelection;
        }
        return null;
      }

      // Authenticated: wait for metadata providers to finish loading
      final isMetadataLoading =
          profileAsync.isLoading ||
          isDeviceRegisteredAsync.isLoading ||
          isKycVerifiedAsync.isLoading ||
          isBiometricEnrolledAsync.isLoading;

      if (isMetadataLoading) {
        return null; // RouterNotifier will call notifyListeners() when they resolve
      }

      // If profile failed to load, send to role selection to avoid a white screen
      if (profile == null || profileAsync.hasError) {
        AppLogger.warning(
          '[ROUTER] Profile null or error after loading — redirecting to role selection.',
          category: LogCategory.auth,
        );
        return RouteNames.roleSelection;
      }

      final kycVerified = isKycVerifiedAsync.valueOrNull ?? false;

      final isVerifying2FA =
          state.matchedLocation == RouteNames.twoFactorVerification;
      final isVerifyingKYC =
          state.matchedLocation == RouteNames.kycVerification;
      final isEnrollingBiometrics =
          state.matchedLocation == RouteNames.biometricEnrollment;

      // Gate 1: Two-Factor Authentication (Device Registration) - Bypassed/Removed completely
      // (All accounts are considered pre-registered and bypass 2FA check)

      // Gate 2: KYC Verification (Only for patients)
      if (profile.role == 'patient' && !kycVerified) {
        if (!isVerifyingKYC) {
          return RouteNames.kycVerification;
        }
        return null;
      }

      // Gate 3: Biometric Enrollment - Bypassed/Removed completely
      // (Biometric features are disabled and bypass check)

      // Fully verified — redirect from auth/verification screens to the dashboard
      if (isAuthRoute ||
          isVerifying2FA ||
          isVerifyingKYC ||
          isEnrollingBiometrics) {
        return _getDashboardRoute(profile);
      }

      // Enforce role-specific paths
      final path = state.matchedLocation;
      final expectedPrefix = _rolePrefix(profile.role);
      final isCommonRoute =
          path == RouteNames.profile ||
          path == RouteNames.notifications ||
          path == RouteNames.biometricEnrollment ||
          path == RouteNames.kycVerification ||
          path == RouteNames.deviceManagement ||
          path == RouteNames.twoFactorVerification;

      if (!isCommonRoute &&
          expectedPrefix != null &&
          !path.startsWith(expectedPrefix)) {
        return _getDashboardRoute(profile);
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
        path: RouteNames.twoFactorVerification,
        name: 'twoFactorVerification',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          final userId =
              extras?['userId'] as String? ??
              SupabaseService.instance.currentUser?.id ??
              '';
          final email =
              extras?['email'] as String? ??
              SupabaseService.instance.currentUser?.email ??
              '';
          final codeType =
              extras?['codeType'] as TwoFactorCodeType? ??
              TwoFactorCodeType.email;
          return TwoFactorVerificationScreen(
            userId: userId,
            email: email,
            codeType: codeType,
            onVerified: () async {
              await ref
                  .read(authNotifierProvider.notifier)
                  .completeTwoFactor(
                    registerDevice: true,
                    enableBiometric: true,
                  );
              ref.invalidate(isDeviceRegisteredProvider);
            },
          );
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
          return PatientRecordScreen(
            patientId: patientId,
            patientName: patientName,
          );
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
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          final patientId = extras?['patientId'] as String?;
          final patientName = extras?['patientName'] as String?;
          return PrescriptionHistoryScreen(
            patientId: patientId,
            patientName: patientName,
          );
        },
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
    errorBuilder:
        (context, state) =>
            Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
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
