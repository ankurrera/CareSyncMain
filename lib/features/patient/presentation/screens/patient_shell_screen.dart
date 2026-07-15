import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/route_names.dart';
import '../widgets/cs_floating_nav_bar.dart';

/// Persistent shell that wraps the 4 main patient tab screens.
/// The [CSFloatingNavBar] lives here so it stays visible across all tabs.
class PatientShellScreen extends StatefulWidget {
  /// The child widget provided by GoRouter's ShellRoute (the active tab screen).
  final Widget child;

  const PatientShellScreen({super.key, required this.child});

  @override
  State<PatientShellScreen> createState() => _PatientShellScreenState();
}

class _PatientShellScreenState extends State<PatientShellScreen> {
  // Maps each tab index to its route path
  static const List<String> _tabRoutes = [
    RouteNames.patientDashboard, // 0 – Home
    RouteNames.patientMedicalHistory, // 1 – Records
    RouteNames.patientEmergency, // 2 – Emergency
    RouteNames.patientProfile, // 3 – Profile
  ];

  int _selectedIndex = 0;

  /// Derive the active tab from the current location so pressing Back
  /// on a child page still highlights the correct tab.
  int _indexForLocation(String location) {
    if (location.startsWith(RouteNames.patientProfile)) return 3;
    if (location.startsWith(RouteNames.patientEmergency)) return 2;
    if (location.startsWith(RouteNames.patientMedicalHistory)) return 1;
    return 0;
  }

  void _onTabTap(int idx) {
    if (idx == _selectedIndex) return; // no-op on same tab
    setState(() => _selectedIndex = idx);
    context.go(_tabRoutes[idx]);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the indicator in sync if the user navigates via back button
    final currentLocation = GoRouterState.of(context).uri.toString();
    final derivedIndex = _indexForLocation(currentLocation);
    if (derivedIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = derivedIndex);
      });
    }

    final mq = MediaQuery.of(context);
    // Nav bar visual height: 64px pill + 16px gap (both defined in CSFloatingNavBar)
    // The device bottom safe-area is already in mq.padding.bottom, so we add only the pill + gap.
    const double navBarExtraBottom = 64.0 + 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Inject extra bottom padding so child screens scroll above the nav bar
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                bottom: mq.padding.bottom + navBarExtraBottom,
              ),
            ),
            child: widget.child,
          ),

          // Floating nav bar overlaid at the bottom — always on top
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CSFloatingNavBar(
              selectedIndex: _selectedIndex,
              items: kCSNavItems,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}
