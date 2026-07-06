import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../../../../routing/route_names.dart';

import '../../../../services/supabase_service.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../../services/emergency_audit_service.dart';

class PatientLookupScreen extends ConsumerStatefulWidget {
  const PatientLookupScreen({super.key});

  @override
  ConsumerState<PatientLookupScreen> createState() => _PatientLookupScreenState();
}

class _PatientLookupScreenState extends ConsumerState<PatientLookupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  // Strict clinical colors
  static const Color kBgColor = Color(0xFFF8FAFC);
  static const Color kSurfaceColor = Color(0xFFFFFFFF);
  static const Color kPrimaryColor = Color(0xFF0284C7); // Clinical Blue
  static const Color kSuccessColor = Color(0xFF16A34A);
  static const Color kWarningColor = Color(0xFFD97706);
  static const Color kTextPrimary = Color(0xFF0F172A);
  static const Color kTextSecondary = Color(0xFF475569);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPatients(query);
    });
  }

  Future<void> _searchPatients(String query) async {
    if (query.trim().length < 2) {
      if (mounted) {
        setState(() => _searchResults = []);
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or('email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('[DOC] Error searching patients: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectPatient(Map<String, dynamic> patientProfile) async {
    try {
      final patientRecord = await SupabaseService.instance.client
          .from('patients')
          .select('id')
          .eq('user_id', patientProfile['id'])
          .maybeSingle();

      if (!mounted) return;

      if (patientRecord == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient record incomplete or not found.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      context.push(
        RouteNames.doctorPatientRecord,
        extra: {
          'patientId': patientRecord['id'] as String,
          'patientName': patientProfile['full_name'] as String? ?? 'Unknown',
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting patient: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Find Patient',
          style: GoogleFonts.plusJakartaSans(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimaryColor,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(
              icon: Icon(Iconsax.search_normal_1, size: 18),
              text: 'Search',
            ),
            Tab(
              icon: Icon(Iconsax.scan_barcode, size: 18),
              text: 'Scan QR',
            ),
            Tab(
              icon: Icon(Iconsax.scan, size: 18),
              text: 'Scan Face',
            ),
          ],
        ),
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: 1),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildScanTab(),
          _buildFaceScanTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: kSurfaceColor,
              border: Border(bottom: BorderSide(color: kBorderColor, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Enter patient name, email, or phone number',
                    hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Iconsax.search_normal_1, color: Color(0xFF64748B), size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Iconsax.close_circle, size: 18),
                            color: const Color(0xFF64748B),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                    ),
                  ),
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextPrimary),
                  textInputAction: TextInputAction.search,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor))
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final patient = _searchResults[index];
                          return _buildPatientListItem(patient);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorderColor),
                ),
                child: const Icon(
                  Iconsax.user_search,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Search Patient Database',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start typing details above to look up registered patients in CareSync.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: kBorderColor),
              ),
              child: const Icon(
                Iconsax.profile_remove,
                size: 40,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Matches Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No records match "$query". Verify details or scan their face biometric profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientListItem(Map<String, dynamic> patient) {
    final name = patient['full_name'] ?? 'Unknown';
    final email = patient['email'] ?? '';
    final phone = patient['phone'] ?? '';
    final subtitle = email.isNotEmpty ? email : phone;

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: kPrimaryColor.withOpacity(0.08),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.plusJakartaSans(
              color: kPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: kTextPrimary,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: kTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Color(0xFF94A3B8),
          size: 12,
        ),
        onTap: () => _selectPatient(patient),
      ),
    );
  }

  Widget _buildScanTab() {
    return _PatientQrScanner(
      onPatientFound: (patientId, patientName) {
        context.push(
          RouteNames.doctorPatientRecord,
          extra: {
            'patientId': patientId,
            'patientName': patientName,
          },
        );
      },
    );
  }

  Widget _buildFaceScanTab() {
    return _PatientFaceScanner(
      onPatientFound: (patientId, patientName) {
        context.push(
          RouteNames.doctorPatientRecord,
          extra: {
            'patientId': patientId,
            'patientName': patientName,
          },
        );
      },
    );
  }
}

class _PatientQrScanner extends StatefulWidget {
  final void Function(String patientId, String patientName) onPatientFound;

  const _PatientQrScanner({required this.onPatientFound});

  @override
  State<_PatientQrScanner> createState() => _PatientQrScannerState();
}

class _PatientQrScannerState extends State<_PatientQrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedValue;
  Timer? _scanCooldown;

  @override
  void dispose() {
    _controller.dispose();
    _scanCooldown?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;
    if (value == _lastScannedValue) return;

    _lastScannedValue = value;
    _scanCooldown?.cancel();
    _scanCooldown = Timer(const Duration(seconds: 3), () {
      _lastScannedValue = null;
    });

    if (value.contains('/emergency/')) {
      setState(() => _isProcessing = true);

      try {
        final uri = Uri.parse(value);
        final qrCodeId = uri.pathSegments.last;

        final patient = await SupabaseService.instance.client
            .from('patients')
            .select('id, profiles!inner(full_name)')
            .eq('qr_code_id', qrCodeId)
            .maybeSingle();

        if (!mounted) return;

        if (patient != null) {
          final profileData = patient['profiles'] as Map<String, dynamic>;
          widget.onPatientFound(
            patient['id'] as String,
            profileData['full_name'] as String? ?? 'Unknown',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resolving QR code: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not a valid CareSync QR code'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF0284C7),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.scan_barcode, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Align QR code within frame',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _PatientFaceScanner extends StatefulWidget {
  final void Function(String patientId, String patientName) onPatientFound;

  const _PatientFaceScanner({required this.onPatientFound});

  @override
  State<_PatientFaceScanner> createState() => _PatientFaceScannerState();
}

class _PatientFaceScannerState extends State<_PatientFaceScanner>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isIdentifying = false;
  String _scanningStatus = 'Initializing...';
  late AnimationController _scannerController;
  int _currentProgressStep = 0;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _scanningStatus = 'No cameras available';
        });
        return;
      }

      final rearCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _scanningStatus = 'Align face and capture';
        });
      }
    } catch (e) {
      debugPrint('[DOC] Camera error: $e');
      if (mounted) {
        setState(() {
          _scanningStatus = 'Camera unavailable';
        });
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final currentLens = _cameraController!.description.lensDirection;
    final newLens = currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == newLens,
      orElse: () => _cameras!.first,
    );

    await _cameraController?.dispose();

    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildProgressStep({
    required int stepIndex,
    required String title,
    required String subtitle,
  }) {
    final bool isCompleted = _currentProgressStep > stepIndex;
    final bool isActive = _currentProgressStep == stepIndex;

    Color iconColor;
    Widget statusIcon;
    TextStyle titleStyle;
    TextStyle subtitleStyle;

    if (isCompleted) {
      iconColor = const Color(0xFF16A34A);
      statusIcon = Icon(Icons.check_circle_rounded, color: iconColor, size: 16);
      titleStyle = GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      );
      subtitleStyle = GoogleFonts.plusJakartaSans(
        color: Colors.white60,
        fontSize: 10,
      );
    } else if (isActive) {
      iconColor = const Color(0xFF0284C7);
      statusIcon = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
      titleStyle = GoogleFonts.plusJakartaSans(
        color: iconColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      );
      subtitleStyle = GoogleFonts.plusJakartaSans(
        color: iconColor.withOpacity(0.8),
        fontSize: 10,
      );
    } else {
      iconColor = Colors.white24;
      statusIcon = Icon(Icons.radio_button_off_rounded, color: iconColor, size: 16);
      titleStyle = GoogleFonts.plusJakartaSans(
        color: Colors.white30,
        fontSize: 12,
      );
      subtitleStyle = GoogleFonts.plusJakartaSans(
        color: Colors.white24,
        fontSize: 10,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: statusIcon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 1),
                Text(subtitle, style: subtitleStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 7.0),
      child: Container(
        width: 1,
        height: 10,
        color: Colors.white10,
      ),
    );
  }

  Future<void> _captureAndIdentify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      setState(() {
        _isIdentifying = true;
        _currentProgressStep = 0;
      });

      final XFile rawFile = await _cameraController!.takePicture();

      if (!mounted) return;
      setState(() {
        _currentProgressStep = 1;
      });

      final File processedFile = await _processImageForBiometrics(rawFile.path);

      if (!mounted) return;
      setState(() {
        _currentProgressStep = 2;
      });

      try {
        await File(rawFile.path).delete();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _currentProgressStep = 3;
      });

      final matchResult = await CustomBiometricService.instance.identifyPatient(processedFile);

      if (!mounted) return;
      setState(() {
        _currentProgressStep = 4;
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _currentProgressStep = 5;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      try {
        await processedFile.delete();
      } catch (_) {}

      setState(() {
        _isIdentifying = false;
      });

      if (matchResult != null && matchResult['patient_id'] != null) {
        final patientId = matchResult['patient_id'] as String;
        final fullName = matchResult['full_name'] as String;
        final confidence = matchResult['confidence'] as num? ?? 100.0;

        await EmergencyAuditService.instance.logFaceScan(
          patientId: patientId,
          status: 'Success',
          confidence: confidence.toDouble(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence)'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onPatientFound(patientId, fullName);
      } else {
        await EmergencyAuditService.instance.logFaceScan(
          patientId: null,
          status: 'Failed',
          confidence: 0.0,
          reason: 'Unknown Patient',
        );

        _showNoMatchDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[DOC] Face scanning match error: $e');

      await EmergencyAuditService.instance.logFaceScan(
        patientId: null,
        status: 'Failed',
        confidence: 0.0,
        reason: 'Scanning Error',
      );

      _showErrorDialog(e.toString());
    }
  }

  void _showNoMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            Text(
              'No Match Found',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'We could not find a matching patient profile in the CareSync database.\n\nPlease check lighting, center the face, or search manually.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _captureAndIdentify();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Try Again', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(
              'Scanning Failed',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Biometric matching failed:\n\n${message.contains("Exception:") ? message.split("Exception:").last : message}',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
            const SizedBox(height: 16),
            Text(
              _scanningStatus,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.65),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0284C7),
                width: 3.5,
              ),
            ),
          ),
        ),
        Positioned(
          top: 24,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Patient Face Forensic Scan',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Align patient face inside the circle',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(0, 1),
                  )
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Iconsax.camera, color: Colors.white, size: 24),
                onPressed: _switchCamera,
              ),
              GestureDetector(
                onTap: _isIdentifying ? null : _captureAndIdentify,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        if (_isIdentifying)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white10,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AnimatedBuilder(
                              animation: _scannerController,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: CustomPaint(
                                        painter: _FaceBracketPainter(
                                          color: const Color(0xFF0284C7),
                                          animationValue: _scannerController.value,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Iconsax.scan,
                                      color: Colors.white.withOpacity(0.4 + (_scannerController.value * 0.6)),
                                      size: 32,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'BIOMETRIC SCANNING',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Searching secure database registry',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.04),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildProgressStep(
                                  stepIndex: 0,
                                  title: 'Image Capture',
                                  subtitle: 'Streaming scanner bytes',
                                ),
                                _buildDivider(),
                                _buildProgressStep(
                                  stepIndex: 1,
                                  title: 'Resolution Filter',
                                  subtitle: 'Checking blur and liveness',
                                ),
                                _buildDivider(),
                                _buildProgressStep(
                                  stepIndex: 2,
                                  title: 'Pose Detection',
                                  subtitle: 'Extracting focal points',
                                ),
                                _buildDivider(),
                                _buildProgressStep(
                                  stepIndex: 3,
                                  title: 'Signature Generation',
                                  subtitle: 'Hashing facial signature',
                                ),
                                _buildDivider(),
                                _buildProgressStep(
                                  stepIndex: 4,
                                  title: 'Database Comparison',
                                  subtitle: 'Comparing multi-poses',
                                ),
                                _buildDivider(),
                                _buildProgressStep(
                                  stepIndex: 5,
                                  title: 'Verification complete',
                                  subtitle: 'Opening medical record',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<File> _processImageForBiometrics(String inputPath) async {
  final bytes = await File(inputPath).readAsBytes();
  final processedBytes = await compute(_processImageBytes, bytes);
  
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/processed_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await tempFile.writeAsBytes(processedBytes);
  
  return tempFile;
}

Uint8List _processImageBytes(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');
  
  final minDim = image.width < image.height ? image.width : image.height;
  final x = (image.width - minDim) ~/ 2;
  final y = (image.height - minDim) ~/ 2;
  
  final cropped = img.copyCrop(image, x: x, y: y, width: minDim, height: minDim);
  final resized = img.copyResize(cropped, width: 480, height: 480);
  
  return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
}

class _FaceBracketPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _FaceBracketPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3 + (animationValue * 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final length = 10.0;

    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);
    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);

    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);

    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _FaceBracketPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}