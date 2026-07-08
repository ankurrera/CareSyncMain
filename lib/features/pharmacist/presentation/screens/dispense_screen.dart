import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/biometric_service.dart';
import '../../../../services/custom_biometric_service.dart';

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

  Future<void> _loadPatientPrescriptions(String qrCodeId) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
    });

    try {
      // Get patient by QR code
      final patient = await SupabaseService.instance.client
          .from('patients')
          .select('id, user_id, profiles!inner(full_name, email)')
          .eq('qr_code_id', qrCodeId)
          .maybeSingle();

      if (patient == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isScanning = true);
        }
        return;
      }

      // Get active prescriptions
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
      // Fallback: support scanning just the plain QR ID itself
      _loadPatientPrescriptions(value);
    }
  }

  Future<void> _dispensePrescription(Map<String, dynamic> prescription) async {
    final items = prescription['prescription_items'] as List? ?? [];
    final rxItemIdList = items.map((i) => i['id'] as String).toList();
    
    // Get checked items for this prescription
    final selectedItemIds = rxItemIdList.where((id) => _selectedItems[id] == true).toList();
    
    if (selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one medication to dispense'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Dispensing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispense ${selectedItemIds.length} selected medication(s) for prescription:\n"${prescription['diagnosis'] ?? 'No diagnosis'}"?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dispense Notes (Optional)',
                hintText: 'e.g., Generic brand substituted, counseling provided...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacist),
            child: const Text('Dispense'),
          ),
        ],
      ),
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
      final confirmVerify = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Iconsax.security_safe, color: AppColors.error, size: 28),
              const SizedBox(width: 8),
              Text(
                'Controlled Substance',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'This prescription contains controlled substances (narcotics/stimulants). '
            'By law, biometric facial verification of the patient is required before dispensing.\n\n'
            'Please scan the patient\'s face to proceed.',
            style: GoogleFonts.plusJakartaSans(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Iconsax.frame_1),
              label: Text(
                'Scan Patient Face',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pharmacist,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );

      if (confirmVerify != true) return;

      // Initiate camera to scan patient face
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Facial scan cancelled. Dispensation aborted.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);

      try {
        final identifyResult = await CustomBiometricService.instance.identifyPatientDetailed(
          File(image.path),
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (identifyResult.status == BiometricResultStatus.success && identifyResult.patientId != null) {
          final expectedUserId = _patient!['user_id'] as String?;
          final currentPatientName = _patient!['profiles']['full_name'] as String? ?? 'Unknown';

          if (identifyResult.patientId == expectedUserId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Patient Biometric Verified: $currentPatientName (${identifyResult.confidence?.toStringAsFixed(1)}% match)',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            // Patient mismatch!
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Icon(Iconsax.warning_2, color: AppColors.error, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Security Mismatch',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Text(
                  'Biometric verification failed.\n\n'
                  'Expected Patient: $currentPatientName\n'
                  'Identified Patient: ${identifyResult.fullName ?? "Unknown"}\n\n'
                  'The dispensing of controlled substances has been blocked for patient safety.',
                  style: GoogleFonts.plusJakartaSans(height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: GoogleFonts.plusJakartaSans()),
                  ),
                ],
              ),
            );
            return;
          }
        } else {
          // Face did not match database
          final errMessage = CustomBiometricService.instance.mapStatusToErrorMessage(
            identifyResult.status,
            identifyResult.errorMessage,
            errorCode: identifyResult.errorCode,
          );
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Iconsax.warning_2, color: AppColors.error, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Verification Failed',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                'Could not verify patient\'s biometric identity.\n\n'
                'Detail: $errMessage\n\n'
                'Dispensing controlled substances is legally restricted without verified biometric authentication.',
                style: GoogleFonts.plusJakartaSans(height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.plusJakartaSans()),
                ),
              ],
            ),
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric microservice query error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    // Biometric Verification for Pharmacist
    try {
      final isBioAvailable = await BiometricService.instance.isBiometricAvailable();
      if (isBioAvailable) {
        final authenticated = await BiometricService.instance.authenticate(
          reason: 'Scan your biometric to authorize this medication dispensation',
          biometricOnly: false, // fallback to device PIN/passcode
        );
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication failed. Dispensation aborted.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      } else {
        if (!mounted) return;
        // Fallback dialog when biometrics are not configured or available (e.g. emulator)
        final passcodeConfirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Biometric Offline'),
            content: const Text(
              'Biometrics are not set up or supported on this device. '
              'Do you want to authorize this dispensation using your session credentials?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abort'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacist),
                child: const Text('Authorize'),
              ),
            ],
          ),
        );
        if (passcodeConfirmed != true) return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Record dispensing
      await SupabaseService.instance.recordDispensing(
        prescriptionId: prescription['id'] as String,
        patientId: _patient!['id'] as String,
        notes: notesController.text.trim(),
        itemsDispensed: selectedItemIds,
      );

      // Mark prescription items as dispensed
      for (final itemId in selectedItemIds) {
        await SupabaseService.instance.client
            .from('prescription_items')
            .update({'is_dispensed': true})
            .eq('id', itemId);
      }

      // Check if all items in this prescription are now dispensed
      final allItems = prescription['prescription_items'] as List? ?? [];
      final undispensedItems = allItems.where((item) {
        final itemId = item['id'] as String;
        final isNowDispensed = selectedItemIds.contains(itemId);
        final wasAlreadyDispensed = item['is_dispensed'] as bool? ?? false;
        return !isNowDispensed && !wasAlreadyDispensed;
      });

      if (undispensedItems.isEmpty) {
        // Update prescription status to completed
        await SupabaseService.instance.client
            .from('prescriptions')
            .update({'status': 'completed'})
            .eq('id', prescription['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medications dispensed successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Reload prescriptions
        final qrCodeId = await SupabaseService.instance.client
            .from('patients')
            .select('qr_code_id')
            .eq('id', _patient!['id'])
            .single();
        _loadPatientPrescriptions(qrCodeId['qr_code_id'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispense Medication'),
        actions: [
          if (_patient != null)
            IconButton(
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan New Patient',
            ),
        ],
      ),
      body: _isScanning
          ? _buildScanner()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPrescriptionList(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.pharmacist,
                width: 3,
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan patient\'s QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionList() {
    final dateFormat = DateFormat('MMM d, yyyy');
    final profileData = _patient!['profiles'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pharmacist.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.pharmacist.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.pharmacist,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.pharmacist,
                        ),
                      ),
                      Text(
                        profileData['full_name'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profileData['email'] != null)
                        Text(
                          profileData['email'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Prescriptions
          Text(
            'Active Prescriptions (${_prescriptions.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_prescriptions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No active prescriptions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All prescriptions have been dispensed',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
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

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rx['diagnosis'] as String? ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. ${doctor?['full_name'] ?? 'Unknown'} • ${dateFormat.format(DateTime.parse(rx['created_at'] as String))}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...items.map((item) {
                              final itemId = item['id'] as String;
                              final isDispensed = item['is_dispensed'] as bool? ?? false;
                              
                              if (isDispensed) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item['medicine_name']} - ${item['dosage']}',
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Dispensed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final isControlled = _controlledSubstances.any(
                                (substance) => (item['medicine_name'] as String? ?? '').toLowerCase().contains(substance)
                              );

                              return CheckboxListTile(
                                value: _selectedItems[itemId] ?? false,
                                activeColor: AppColors.pharmacist,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['medicine_name']} - ${item['dosage']}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isControlled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Iconsax.security_safe,
                                              color: AppColors.error,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'CONTROLLED',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: AppColors.error,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${item['frequency']} for ${item['duration'] ?? "N/A"}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedItems[itemId] = val ?? false;
                                  });
                                },
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    // Dispense button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pharmacist.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _dispensePrescription(rx),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Dispense Selected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pharmacist,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
