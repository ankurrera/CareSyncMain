import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/design/circular_icon_button.dart';
import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/biometric_service.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../shared/presentation/widgets/biometric_scan_hud.dart';
import '../../../../services/connectivity_service.dart';

class DispenseScreen extends ConsumerStatefulWidget {
  final String? initialQrCodeId;
  const DispenseScreen({super.key, this.initialQrCodeId});

  @override
  ConsumerState<DispenseScreen> createState() => _DispenseScreenState();
}

class _DispenseScreenState extends ConsumerState<DispenseScreen> {
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _prescriptions = [];
  Map<String, bool> _selectedItems = {};
  bool _isLoading = false;
  bool _isScanning = true;
  bool _isIdentifying = false;
  String _scanningStatus = 'Initializing...';

  static const _controlledSubstances = [
    'morphine',
    'fentanyl',
    'oxycodone',
    'codeine',
    'tramadol',
    'xanax',
    'diazepam',
    'adderall',
    'ritalin',
    'methadone',
    'vicodin',
    'hydrocodone',
    'buprenorphine',
    'alprazolam',
    'lorazepam',
  ];

  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    if (widget.initialQrCodeId != null) {
      _isScanning = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPatientPrescriptions(widget.initialQrCodeId!);
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.tokens.error : context.tokens.accent,
      ),
    );
  }

  Future<void> _loadPatientPrescriptions(String qrCodeId) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
    });

    try {
      final patient =
          await SupabaseService.instance.client
              .from('patients')
              .select('id, user_id, profiles!inner(full_name, email)')
              .eq('qr_code_id', qrCodeId)
              .maybeSingle();

      if (patient == null) {
        if (mounted) {
          _snack('Patient not found', error: true);
          setState(() => _isScanning = true);
        }
        return;
      }

      final prescriptions = await SupabaseService.instance.client
          .from('prescriptions')
          .select('''
            *,
            prescription_items(*),
            doctor:profiles!doctor_id(full_name)
          ''')
          .eq('patient_id', patient['id'])
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final newSelectedItems = <String, bool>{};
      for (final rx in prescriptions) {
        final items = rx['prescription_items'] as List? ?? [];
        for (final item in items) {
          final itemId = item['id'] as String;
          final isDispensed = item['is_dispensed'] as bool? ?? false;
          if (!isDispensed) {
            newSelectedItems[itemId] = true;
          }
        }
      }

      setState(() {
        _patient = patient;
        _prescriptions = List<Map<String, dynamic>>.from(prescriptions);
        _selectedItems = newSelectedItems;
      });
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', error: true);
        setState(() => _isScanning = true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isLoading || !_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    if (value.contains('/emergency/')) {
      final uri = Uri.parse(value);
      final qrCodeId = uri.pathSegments.last;
      _loadPatientPrescriptions(qrCodeId);
    } else {
      _loadPatientPrescriptions(value);
    }
  }

  Future<void> _dispensePrescription(Map<String, dynamic> prescription) async {
    final items = prescription['prescription_items'] as List? ?? [];
    final rxItemIdList = items.map((i) => i['id'] as String).toList();

    final selectedItemIds =
        rxItemIdList.where((id) => _selectedItems[id] == true).toList();

    if (selectedItemIds.isEmpty) {
      _snack('Please select at least one medication to dispense');
      return;
    }

    final notesController = TextEditingController();
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirm Dispensing',
                textAlign: TextAlign.center,
                style: t.sheetTitle,
              ),
              const SizedBox(height: 12),
              Text(
                'Dispense ${selectedItemIds.length} selected medication(s) for prescription:\n"${prescription['diagnosis'] ?? 'No diagnosis'}"?',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 2,
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'Dispense Notes (Optional)',
                  hintText:
                      'e.g., Generic brand substituted, counseling provided...',
                  filled: true,
                  fillColor: t.scaffold,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CSTwoButtonRow(
                cancelLabel: 'Cancel',
                confirmLabel: 'Dispense',
                onCancel: () => Navigator.pop(ctx, false),
                onConfirm: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    // Controlled Substance Check & Patient Biometric Verification
    final isControlledPrescription = items.any((item) {
      final itemId = item['id'] as String;
      if (!selectedItemIds.contains(itemId)) return false;

      final name = (item['medicine_name'] as String? ?? '').toLowerCase();
      return _controlledSubstances.any((substance) => name.contains(substance));
    });

    if (isControlledPrescription) {
      if (!mounted) return;
      final confirmVerify = await showConfirmSheet(
        context,
        icon: Iconsax.security_safe,
        title: 'Controlled Substance',
        message:
            'This prescription contains controlled substances (narcotics/stimulants). '
            'By law, biometric facial verification of the patient is required before dispensing.\n\n'
            'Please scan the patient\'s face to proceed.',
        confirmLabel: 'Scan Patient Face',
      );

      if (!confirmVerify) return;

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        if (mounted) {
          _snack('Facial scan cancelled. Dispensation aborted.', error: true);
        }
        return;
      }

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _isIdentifying) {
          setState(() {
            _scanningStatus = 'Analyzing biometric coordinates...';
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isIdentifying) {
          setState(() {
            _scanningStatus = 'Searching CareSync registry...';
          });
        }
      });

      try {
        final identifyResult = await CustomBiometricService.instance
            .identifyPatientDetailed(File(image.path));

        if (!mounted) return;
        setState(() {
          _isIdentifying = false;
        });

        if (identifyResult.status == BiometricResultStatus.success &&
            identifyResult.patientId != null) {
          final expectedPatientId = _patient!['id'] as String?;
          final currentPatientName =
              _patient!['profiles']['full_name'] as String? ?? 'Unknown';

          if (identifyResult.patientId == expectedPatientId) {
            _snack(
              'Patient Biometric Verified: $currentPatientName (${identifyResult.confidence?.toStringAsFixed(1)}% match)',
            );
          } else {
            // Patient mismatch!
            await showAlertSheet(
              context,
              icon: Iconsax.warning_2,
              title: 'Security Mismatch',
              message:
                  'Biometric verification failed.\n\n'
                  'Expected Patient: $currentPatientName\n'
                  'Identified Patient: ${identifyResult.fullName ?? "Unknown"}\n\n'
                  'The dispensing of controlled substances has been blocked for patient safety.',
              buttonLabel: 'Close',
            );
            return;
          }
        } else {
          final errMessage = CustomBiometricService.instance
              .mapStatusToErrorMessage(
                identifyResult.status,
                identifyResult.errorMessage,
                errorCode: identifyResult.errorCode,
              );
          await showAlertSheet(
            context,
            icon: Iconsax.warning_2,
            title: 'Verification Failed',
            message:
                'Could not verify patient\'s biometric identity.\n\n'
                'Detail: $errMessage\n\n'
                'Dispensing controlled substances is legally restricted without verified biometric authentication.',
            buttonLabel: 'Close',
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isIdentifying = false);
          _snack('Biometric microservice query error: $e', error: true);
        }
        return;
      }
    }

    // Biometric Verification for Pharmacist
    try {
      final isBioAvailable =
          await BiometricService.instance.isBiometricAvailable();
      if (isBioAvailable) {
        final authenticated = await BiometricService.instance.authenticate(
          reason:
              'Scan your biometric to authorize this medication dispensation',
          biometricOnly: false,
        );
        if (!authenticated) {
          if (mounted) {
            _snack(
              'Biometric authentication failed. Dispensation aborted.',
              error: true,
            );
          }
          return;
        }
      } else {
        if (!mounted) return;
        final passcodeConfirmed = await showConfirmSheet(
          context,
          icon: Iconsax.finger_scan,
          title: 'Biometric Offline',
          message:
              'Biometrics are not set up or supported on this device. '
              'Do you want to authorize this dispensation using your session credentials?',
          confirmLabel: 'Authorize',
          cancelLabel: 'Abort',
        );
        if (!passcodeConfirmed) return;
      }
    } catch (e) {
      if (mounted) {
        _snack('Verification error: $e', error: true);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.recordDispensing(
        prescriptionId: prescription['id'] as String,
        patientId: _patient!['id'] as String,
        notes: notesController.text.trim(),
        itemsDispensed: selectedItemIds,
      );

      if (mounted) {
        _snack('Medications dispensed successfully');

        final qrCodeId =
            await SupabaseService.instance.client
                .from('patients')
                .select('qr_code_id')
                .eq('id', _patient!['id'])
                .single();
        _loadPatientPrescriptions(qrCodeId['qr_code_id'] as String);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', error: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetScan() {
    setState(() {
      _patient = null;
      _prescriptions = [];
      _selectedItems = {};
      _isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final topInset =
        MediaQuery.of(context).padding.top + AppSpacing.appBarHeight;
    final connectivity = ref.watch(connectivityStatusProvider).valueOrNull;
    final isOffline = connectivity == ConnectivityStatus.offline;

    final Widget content =
        _isScanning
            ? _buildScanner()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildPrescriptionList(isOffline);

    return Scaffold(
      backgroundColor: t.scaffold,
      body: Stack(
        children: [
          // Scanner is full-bleed; other states sit below the fade bar.
          _isScanning
              ? content
              : Padding(
                padding: EdgeInsets.only(top: topInset),
                child: content,
              ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearFadeAppBar(
              title: 'Dispense Medication',
              actions: [
                if (_patient != null)
                  CircularIconButton(
                    icon: Iconsax.scan_barcode,
                    onTap: _resetScan,
                  ),
              ],
            ),
          ),
          if (_isIdentifying) BiometricScanHud(status: _scanningStatus),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    final t = context.tokens;
    return Stack(
      children: [
        MobileScanner(controller: _scannerController, onDetect: _onDetect),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: t.accent, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan patient\'s QR code',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionList(bool isOffline) {
    final t = context.tokens;
    final dateFormat = DateFormat('MMM d, yyyy');
    final profileData = _patient!['profiles'] as Map<String, dynamic>;
    final patientName = profileData['full_name'] as String? ?? 'Unknown';
    final patientEmail = profileData['email'] as String? ?? '';
    final initials =
        patientName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — Patient Identity Card ——————————————————————————————————————————
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Initials avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (patientEmail.isNotEmpty)
                        Text(
                          patientEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Verified badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.verify, size: 13, color: t.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // — Section header ————————————————————————————————————————————————
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Active Prescriptions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_prescriptions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // — Empty state ——————————————————————————————————————————————————
          if (_prescriptions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(AppSpacing.squircleGrouped),
                border: Border.all(color: t.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.tick_circle, size: 26, color: t.accent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All Clear',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No active prescriptions for this patient.\nAll medications have been dispensed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_prescriptions.length, (index) {
              final rx = _prescriptions[index];
              final items = rx['prescription_items'] as List? ?? [];
              final doctor = rx['doctor'] as Map<String, dynamic>?;
              final date = DateTime.tryParse(rx['created_at'] as String? ?? '');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.squircleGrouped,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Iconsax.receipt_item,
                                size: 18,
                                color: t.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rx['diagnosis'] as String? ??
                                        'Unknown Diagnosis',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Iconsax.user_octagon,
                                        size: 11,
                                        color: t.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Dr. ${doctor?['full_name'] ?? 'Unknown'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.textSecondary,
                                        ),
                                      ),
                                      if (date != null) ...[
                                        Text(
                                          '  •  ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                        Icon(
                                          Iconsax.calendar_1,
                                          size: 11,
                                          color: t.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          dateFormat.format(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (items.isNotEmpty) ...[
                        Divider(
                          height: 1,
                          color: t.divider.withValues(alpha: 0.5),
                        ),
                        // Medications list
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medications',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...items.map((item) {
                                final itemId = item['id'] as String;
                                final isDispensed =
                                    item['is_dispensed'] as bool? ?? false;

                                if (isDispensed) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.scaffold,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: t.textSecondary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${item['medicine_name']} — ${item['dosage']}',
                                              style: TextStyle(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color: t.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Dispensed',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: t.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final isControlled = _controlledSubstances.any(
                                  (s) =>
                                      (item['medicine_name'] as String? ?? '')
                                          .toLowerCase()
                                          .contains(s),
                                );
                                final isSelected =
                                    _selectedItems[itemId] ?? false;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap:
                                        () => setState(
                                          () =>
                                              _selectedItems[itemId] =
                                                  !isSelected,
                                        ),
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? t.accent.withValues(
                                                  alpha: 0.07,
                                                )
                                                : t.scaffold,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color:
                                                  isSelected
                                                      ? t.accent
                                                      : Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    isSelected
                                                        ? t.accent
                                                        : t.textSecondary
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                width: 1.5,
                                              ),
                                            ),
                                            child:
                                                isSelected
                                                    ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color: Colors.white,
                                                    )
                                                    : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${item['medicine_name']} — ${item['dosage']}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: t.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isControlled)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: t.error
                                                              .withValues(
                                                                alpha: 0.09,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'CONTROLLED',
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: t.error,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${item['frequency']} · ${item['duration'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: t.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      // Footer action
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: CSPrimaryButton(
                          label:
                              isOffline
                                  ? 'Offline — Unavailable'
                                  : 'Dispense Selected',
                          icon: Icons.medication_rounded,
                          onPressed:
                              (isOffline || _isLoading)
                                  ? null
                                  : () => _dispensePrescription(rx),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
