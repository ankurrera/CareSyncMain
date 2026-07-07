import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
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
      onCancel: () {
        _tabController.animateTo(0);
      },
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

class _PatientQrScannerState extends State<_PatientQrScanner>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String _scanningStatus = 'Initializing...';
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    if (_isProcessing) return;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _scanningStatus = 'Scanning QR Code...';
      });

      final BarcodeCapture? barcodes = await _controller.analyzeImage(image.path);

      if (!mounted) return;

      final barcode = barcodes?.barcodes.firstOrNull;
      if (barcode?.rawValue == null) {
        setState(() => _isProcessing = false);
        HapticFeedback.heavyImpact();
        _showErrorSnackBar('No QR code detected in the image.');
        return;
      }

      final value = barcode!.rawValue!;
      
      // Parse QR Code ID (UUID)
      String? qrCodeId;
      if (value.contains('/emergency/')) {
        final uri = Uri.parse(value);
        qrCodeId = uri.pathSegments.last;
      } else {
        // Basic UUID validation
        final uuidRegex = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (uuidRegex.hasMatch(value)) {
          qrCodeId = value;
        }
      }

      if (qrCodeId == null) {
        setState(() => _isProcessing = false);
        HapticFeedback.heavyImpact();
        _showErrorSnackBar('Not a valid CareSync QR code.');
        return;
      }

      setState(() {
        _scanningStatus = 'Resolving patient ID...';
      });

      final patient = await SupabaseService.instance.client
          .from('patients')
          .select('id, profiles!inner(full_name)')
          .eq('qr_code_id', qrCodeId)
          .maybeSingle();

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (patient != null) {
        final profileData = patient['profiles'] as Map<String, dynamic>;
        final patientId = patient['id'] as String;
        final patientName = profileData['full_name'] as String? ?? 'Unknown';

        HapticFeedback.mediumImpact();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onPatientFound(patientId, patientName);
          }
        });
      } else {
        HapticFeedback.heavyImpact();
        _showErrorSnackBar('Patient profile not found.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        HapticFeedback.heavyImpact();
        _showErrorSnackBar('Scanning Error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main view configuration
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.scan_barcode,
                  size: 64,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'QR Profile Lookup',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Point the camera at the patient\'s emergency pass QR code to instantly pull their medical record.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _scanQrCode,
                icon: const Icon(Iconsax.scan, size: 20),
                label: Text(
                  'Scan Patient QR Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        
        // QR Scanning dialog overlay
        if (_isProcessing)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      width: 270,
                      height: 240,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _scannerController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 84,
                                    height: 84,
                                    child: CustomPaint(
                                      painter: _FaceBracketPainter(
                                        color: const Color(0xFF0284C7),
                                        animationValue: _scannerController.value,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Iconsax.scan_barcode,
                                    color: Colors.white.withOpacity(0.4 + (_scannerController.value * 0.6)),
                                    size: 36,
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'QR CODE SCAN',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _scanningStatus,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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

class _PatientFaceScanner extends StatefulWidget {
  final void Function(String patientId, String patientName) onPatientFound;
  final VoidCallback? onCancel;

  const _PatientFaceScanner({
    required this.onPatientFound,
    this.onCancel,
  });

  @override
  State<_PatientFaceScanner> createState() => _PatientFaceScannerState();
}

class _PatientFaceScannerState extends State<_PatientFaceScanner>
    with SingleTickerProviderStateMixin {
  bool _isIdentifying = false;
  String _scanningStatus = 'Initializing...';
  late AnimationController _scannerController;
  BiometricCancelToken? _activeCancelToken;
  bool _cooldownActive = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _activeCancelToken?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanFace() async {
    if (_cooldownActive) return;
    _activeCancelToken?.cancel();
    final cancelToken = BiometricCancelToken();
    _activeCancelToken = cancelToken;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;
      if (cancelToken.isCancelled) return;

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _isIdentifying && !cancelToken.isCancelled) {
          setState(() {
            _scanningStatus = 'Analyzing biometric coordinates...';
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isIdentifying && !cancelToken.isCancelled) {
          setState(() {
            _scanningStatus = 'Searching CareSync registry...';
          });
        }
      });

      final File processedFile = await _processImageForBiometrics(image.path);

      if (cancelToken.isCancelled) return;
      if (!mounted) return;

      final identifyResult = await CustomBiometricService.instance.identifyPatientDetailed(
        processedFile,
        cancelToken: cancelToken,
      );

      if (cancelToken.isCancelled) return;
      if (!mounted) return;

      setState(() {
        _isIdentifying = false;
      });

      try {
        await processedFile.delete();
      } catch (_) {}

      if (identifyResult.status == BiometricResultStatus.success && identifyResult.patientId != null) {
        setState(() {
          _cooldownActive = true;
        });
        _cooldownTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _cooldownActive = false;
            });
          }
        });

        final patientId = identifyResult.patientId!;
        final fullName = identifyResult.fullName ?? 'Unknown';
        final confidence = identifyResult.confidence ?? 100.0;

        await EmergencyAuditService.instance.logFaceScan(
          patientId: patientId,
          status: 'Success',
          confidence: confidence,
        );

        HapticFeedback.mediumImpact();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence)'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );
            widget.onPatientFound(patientId, fullName);
          }
        });
      } else {
        final friendlyMessage = CustomBiometricService.instance.mapStatusToErrorMessage(
          identifyResult.status,
          identifyResult.errorMessage,
          errorCode: identifyResult.errorCode,
        );

        await EmergencyAuditService.instance.logFaceScan(
          patientId: null,
          status: 'Failed',
          confidence: 0.0,
          reason: friendlyMessage,
        );

        HapticFeedback.heavyImpact();

        if (identifyResult.status == BiometricResultStatus.noMatch) {
          _showNoMatchDialog(message: friendlyMessage);
        } else {
          _showErrorDialog(friendlyMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[DOC] Face scan identification error: $e');

      await EmergencyAuditService.instance.logFaceScan(
        patientId: null,
        status: 'Failed',
        confidence: 0.0,
        reason: 'Scanning Error',
      );

      HapticFeedback.heavyImpact();

      _showErrorDialog(e.toString());
    }
  }

  void _showNoMatchDialog({String message = 'No Matching Patient Found'}) {
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
          '$message\n\nWe could not find a matching patient profile in the CareSync database. Please check lighting, center the face, or search manually.',
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
              _scanFace();
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
    return Stack(
      children: [
        // Main view configuration
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.user_search,
                  size: 64,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Biometric Patient Lookup',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'CareSync allows providers to scan a patient\'s face to instantly lookup and access their digital health records in emergency situations.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _cooldownActive ? null : _scanFace,
                icon: const Icon(Iconsax.scan, size: 20),
                label: Text(
                  _cooldownActive ? 'Cooldown Active' : 'Scan Patient Face',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Face ID scanning dialog overlay
        if (_isIdentifying)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      width: 270,
                      height: 240,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F11).withOpacity(0.85), // Premium slate/black frosted
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Apple Face ID style breathing brackets and abstract vector face
                          AnimatedBuilder(
                            animation: _scannerController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 84,
                                    height: 84,
                                    child: CustomPaint(
                                      painter: _FaceBracketPainter(
                                        color: const Color(0xFF0284C7),
                                        animationValue: _scannerController.value,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: CustomPaint(
                                      painter: _FaceIdScannerPainter(
                                        color: Colors.white,
                                        animationValue: _scannerController.value,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'FACE ID SCAN',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Compact loader and status text (avoids truncation)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _scanningStatus,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
  var image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');
  
  image = img.bakeOrientation(image);
  
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

    final length = 14.0;
    final r = 6.0; // Corner radius for the brackets

    // Top Left Corner
    final pathTL = Path()
      ..moveTo(0, length)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(length, 0);
    canvas.drawPath(pathTL, paint);

    // Top Right Corner
    final pathTR = Path()
      ..moveTo(size.width, length)
      ..lineTo(size.width, r)
      ..quadraticBezierTo(size.width, 0, size.width - r, 0)
      ..lineTo(size.width - length, 0);
    canvas.drawPath(pathTR, paint);

    // Bottom Left Corner
    final pathBL = Path()
      ..moveTo(0, size.height - length)
      ..lineTo(0, size.height - r)
      ..quadraticBezierTo(0, size.height, r, size.height)
      ..lineTo(length, size.height);
    canvas.drawPath(pathBL, paint);

    // Bottom Right Corner
    final pathBR = Path()
      ..moveTo(size.width, size.height - length)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(size.width - length, size.height);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceBracketPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _FaceIdScannerPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _FaceIdScannerPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4 + (animationValue * 0.4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double w = size.width;
    final double h = size.height;

    final facePath = Path()
      // Left eye
      ..moveTo(w * 0.35, h * 0.4)
      ..lineTo(w * 0.35, h * 0.42)
      // Right eye
      ..moveTo(w * 0.65, h * 0.4)
      ..lineTo(w * 0.65, h * 0.42)
      // Nose
      ..moveTo(w * 0.5, h * 0.4)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.58, h * 0.55)
      // Mouth (smiling arc)
      ..moveTo(w * 0.38, h * 0.68)
      ..quadraticBezierTo(w * 0.5, h * 0.76, w * 0.62, h * 0.68)
      // Face outline (u-shape)
      ..moveTo(w * 0.25, h * 0.3)
      ..lineTo(w * 0.25, h * 0.58)
      ..quadraticBezierTo(w * 0.25, h * 0.85, w * 0.5, h * 0.85)
      ..quadraticBezierTo(w * 0.75, h * 0.85, w * 0.75, h * 0.58)
      ..lineTo(w * 0.75, h * 0.3);

    canvas.drawPath(facePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdScannerPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}