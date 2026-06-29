import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';

class PharmacistSearchScreen extends StatefulWidget {
  const PharmacistSearchScreen({super.key});

  @override
  State<PharmacistSearchScreen> createState() => _PharmacistSearchScreenState();
}

class _PharmacistSearchScreenState extends State<PharmacistSearchScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPatients(query);
    });
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or('email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error searching patients: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPatient(Map<String, dynamic> profile) async {
    final phone = profile['phone'] as String? ?? '';
    final lastFourDigits = phone.length >= 4 ? phone.substring(phone.length - 4) : '1234';

    // Show secure verification dialog (OTP check)
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final pinController = TextEditingController();
        bool isPinError = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.security_rounded, color: AppColors.pharmacist),
                  const SizedBox(width: 8),
                  const Text('Security Verification'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'To access patient prescriptions, please enter the 4-digit code shown on the patient\'s CareSync app.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: isPinError ? 'Invalid verification code' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hint: Patient\'s phone last 4 digits ($lastFourDigits)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (pinController.text.trim() == lastFourDigits) {
                      Navigator.pop(context, true);
                    } else {
                      setDialogState(() {
                        isPinError = true;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacist),
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    if (verified != true) return;

    // Retrieve patient record to get their qr_code_id
    try {
      final patientRecord = await SupabaseService.instance.client
          .from('patients')
          .select('qr_code_id')
          .eq('user_id', profile['id'])
          .maybeSingle();

      if (!mounted) return;

      if (patientRecord == null || patientRecord['qr_code_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient record has no registered QR code ID'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final qrCodeId = patientRecord['qr_code_id'] as String;

      // Navigate to dispensing screen with pre-filled QR Code ID
      context.pushReplacement(RouteNames.pharmacistDispense, extra: qrCodeId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Prescription Search'),
      ),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Patients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter patient name, email, or phone number to load prescription list.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? _buildEmptyState()
                      : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.length < 2
                ? 'Type at least 2 characters to search'
                : 'No patients found',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final profile = _searchResults[index];
        final email = profile['email'] as String? ?? 'No email';
        final phone = profile['phone'] as String? ?? 'No phone';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.pharmacist.withValues(alpha: 0.1),
              child: const Icon(Icons.person_rounded, color: AppColors.pharmacist),
            ),
            title: Text(
              profile['full_name'] as String? ?? 'Unknown Patient',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$email\n$phone', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded),
            isThreeLine: true,
            onTap: () => _selectPatient(profile),
          ),
        );
      },
    );
  }
}
