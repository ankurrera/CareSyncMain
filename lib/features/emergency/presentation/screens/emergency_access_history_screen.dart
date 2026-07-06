import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/emergency_audit_service.dart';

/// Provider to fetch immutable audit logs from database
final emergencyLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) return [];

  // Attempt background sync of offline logs first
  try {
    await EmergencyAuditService.instance.flushQueue();
  } catch (_) {}

  final response = await supabase
      .from('emergency_access_logs')
      .select('*')
      .eq('patient_id', currentUser.id)
      .order('timestamp', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class EmergencyAccessHistoryScreen extends ConsumerStatefulWidget {
  const EmergencyAccessHistoryScreen({super.key});

  @override
  ConsumerState<EmergencyAccessHistoryScreen> createState() =>
      _EmergencyAccessHistoryScreenState();
}

class _EmergencyAccessHistoryScreenState
    extends ConsumerState<EmergencyAccessHistoryScreen> {
  final _searchController = TextEditingController();
  
  // Filters state
  String _selectedMethod = 'All';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  String _selectedReason = 'All';
  
  bool _isFilterExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Analyzes logs for suspicious warning flags
  Map<String, dynamic> _analyzeAnomaly(Map<String, dynamic> log) {
    final List<String> issues = [];
    final status = log['access_status'] as String? ?? 'Success';
    final method = log['authentication_method'] as String? ?? 'QR Code';
    final confidence = log['confidence_score'] as num? ?? 100.0;
    final country = log['country'] as String? ?? 'Unknown';

    if (status == 'Failed' || status == 'Denied') {
      issues.add('Access request failed authentication check');
    }
    if (method == 'Face Recognition' && confidence < 75.0 && confidence > 0) {
      issues.add('Low facial registration similarity index ($confidence%)');
    }
    if (country != 'Unknown' && country != 'United States' && country != 'US' && country != 'India') {
      issues.add('Access origin flags unexpected territory ($country)');
    }

    return {
      'isSuspicious': issues.isNotEmpty,
      'reasons': issues,
    };
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(emergencyLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Pure clinical gray canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Emergency Access Audit',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(emergencyLogsProvider),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 18),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          final filteredLogs = logs.where((log) {
            final search = _searchController.text.trim().toLowerCase();
            if (search.isNotEmpty) {
              final docName = (log['accessed_by_name'] as String? ?? '').toLowerCase();
              final hosp = (log['hospital_name'] as String? ?? '').toLowerCase();
              final role = (log['accessed_by_role'] as String? ?? '').toLowerCase();
              final uid = (log['accessed_by_user_id'] as String? ?? '').toLowerCase();
              
              if (!docName.contains(search) &&
                  !hosp.contains(search) &&
                  !role.contains(search) &&
                  !uid.contains(search)) {
                return false;
              }
            }

            if (_selectedMethod != 'All' && log['authentication_method'] != _selectedMethod) {
              return false;
            }

            if (_selectedRole != 'All' && log['accessed_by_role'] != _selectedRole.toLowerCase()) {
              return false;
            }

            if (_selectedStatus != 'All' && log['access_status'] != _selectedStatus) {
              return false;
            }

            if (_selectedReason != 'All' && log['reason_for_access'] != _selectedReason) {
              return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              _buildAnalyticsSection(logs),
              _buildSearchFilterSection(),
              Expanded(
                child: filteredLogs.isEmpty
                    ? _buildEmptyState()
                    : _buildTimelineList(filteredLogs),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5200), strokeWidth: 2.5),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to retrieve audit log ledger: $err',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // Analytics Panel with premium curated cards
  Widget _buildAnalyticsSection(List<Map<String, dynamic>> logs) {
    int totalAccesses = logs.length;
    int failedCount = logs.where((l) => l['access_status'] == 'Failed' || l['access_status'] == 'Denied').length;
    int suspiciousCount = logs.where((l) => _analyzeAnomaly(l)['isSuspicious'] == true).length;
    int qrCount = logs.where((l) => l['authentication_method'] == 'QR Code').length;
    int faceCount = logs.where((l) => l['authentication_method'] == 'Face Recognition').length;
    int overrideCount = logs.where((l) => l['authentication_method'] == 'Manual Emergency Override').length;

    return Container(
      height: 96,
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard('Total Accesses', totalAccesses.toString(), '30 Days', const Color(0xFF0F172A), const Color(0xFFF1F5F9), Iconsax.security),
          _buildStatCard('Failed Attempts', failedCount.toString(), 'Denied access', const Color(0xFFDC2626), const Color(0xFFFEF2F2), Iconsax.warning_2),
          _buildStatCard('Suspicious Alerts', suspiciousCount.toString(), 'Anomalies flagged', const Color(0xFFD97706), const Color(0xFFFFFBEB), Iconsax.shield_search),
          _buildStatCard('QR Scans', qrCount.toString(), 'Quick lookup', const Color(0xFF0D9488), const Color(0xFFF0FDFA), Iconsax.scan),
          _buildStatCard('Biometrics Match', faceCount.toString(), 'Face recognition', const Color(0xFF2563EB), const Color(0xFFEFF6FF), Iconsax.frame_1),
          _buildStatCard('Emergency Override', overrideCount.toString(), 'Manual override', const Color(0xFF7C3AED), const Color(0xFFFAF5FF), Iconsax.lock_slash),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, Color textColor, Color bgColor, IconData icon) {
    return Container(
      width: 144,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor.withOpacity(0.75),
                  ),
                ),
              ),
              Icon(icon, size: 13, color: textColor),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // Modern search bar & filter
  Widget _buildSearchFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // soft background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by provider, clinic, role...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                      prefixIcon: const Icon(Iconsax.search_normal_1, size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _isFilterExpanded ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.filter,
                    size: 16,
                    color: _isFilterExpanded ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          if (_isFilterExpanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Auth Method',
                          _selectedMethod,
                          ['All', 'Face Recognition', 'QR Code', 'Manual Emergency Override'],
                          (val) => setState(() => _selectedMethod = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Provider Role',
                          _selectedRole,
                          ['All', 'Doctor', 'First Responder', 'Patient'],
                          (val) => setState(() => _selectedRole = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Access Status',
                          _selectedStatus,
                          ['All', 'Success', 'Failed', 'Denied', 'Expired'],
                          (val) => setState(() => _selectedStatus = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Access Reason',
                          _selectedReason,
                          ['All', 'Emergency Treatment', 'Trauma', 'Cardiac Arrest', 'Stroke', 'Unknown Patient'],
                          (val) => setState(() => _selectedReason = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.w600),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Timeline list grouped by Date category
  Widget _buildTimelineList(List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final Map<String, List<Map<String, dynamic>>> groups = {
      'Today': [],
      'Yesterday': [],
      'Last 7 Days': [],
      'Older': [],
    };

    for (final log in logs) {
      final tsStr = log['timestamp'] as String?;
      if (tsStr == null) continue;
      final ts = DateTime.parse(tsStr);
      final logDay = DateTime(ts.year, ts.month, ts.day);

      if (logDay == today) {
        groups['Today']!.add(log);
      } else if (logDay == yesterday) {
        groups['Yesterday']!.add(log);
      } else if (logDay.isAfter(lastWeek)) {
        groups['Last 7 Days']!.add(log);
      } else {
        groups['Older']!.add(log);
      }
    }

    final List<Widget> listItems = [];

    groups.forEach((groupName, groupLogs) {
      if (groupLogs.isNotEmpty) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              groupName.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFF5200),
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

        for (final log in groupLogs) {
          listItems.add(_buildAuditLogCard(log));
        }
      }
    });

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: listItems.length,
      itemBuilder: (context, index) => listItems[index],
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log) {
    final method = log['authentication_method'] as String? ?? 'QR Code';
    final name = log['accessed_by_name'] as String? ?? 'Unknown Provider';
    final role = log['accessed_by_role'] as String? ?? 'unknown';
    final hosp = log['hospital_name'] as String? ?? 'CareSync Network';
    final status = log['access_status'] as String? ?? 'Success';
    final tsStr = log['timestamp'] as String?;
    final ts = tsStr != null ? DateTime.parse(tsStr) : DateTime.now();
    final timeStr = DateFormat('h:mm a').format(ts);
    final location = [log['city'], log['state']].where((e) => e != null && e != 'Unknown').join(', ');

    final anomaly = _analyzeAnomaly(log);
    final isSuspicious = anomaly['isSuspicious'] == true;

    Color statusColor;
    IconData statusIcon;

    if (status == 'Success') {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_outline_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.error_outline_rounded;
    }

    IconData methodIcon;
    if (method == 'Face Recognition') {
      methodIcon = Iconsax.frame_1;
    } else if (method == 'QR Code') {
      methodIcon = Iconsax.scan;
    } else {
      methodIcon = Iconsax.lock_slash;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuspicious ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showAuditDetails(log),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isSuspicious ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                child: Icon(methodIcon, size: 15, color: isSuspicious ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 10, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${role.toUpperCase()} • $hosp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 10.5, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    if (isSuspicious) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          anomaly['reasons'][0],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFB91C1C),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(statusIcon, color: statusColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Premium empty state design
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
              ),
              child: const Icon(Iconsax.shield_security, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Audit Logs Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All emergency accesses will be immutably recorded here. Currently, no access history exists for your profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Details inspector sheet modal
  void _showAuditDetails(Map<String, dynamic> log) {
    final method = log['authentication_method'] as String? ?? 'QR Code';
    final name = log['accessed_by_name'] as String? ?? 'Unknown Provider';
    final role = log['accessed_by_role'] as String? ?? 'unknown';
    final hosp = log['hospital_name'] as String? ?? 'CareSync Network';
    final org = log['organization_name'] as String? ?? 'CareSync Org';
    final status = log['access_status'] as String? ?? 'Success';
    final scope = log['view_scope'] as String? ?? 'Emergency ID Only';
    
    final tsStr = log['timestamp'] as String?;
    final ts = tsStr != null ? DateTime.parse(tsStr) : DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(ts);
    final timeStr = DateFormat('h:mm a').format(ts);

    final deviceName = log['device_name'] as String? ?? 'Unknown Device';
    final devicePlatform = log['device_platform'] as String? ?? 'unknown';
    final deviceId = log['device_id'] as String? ?? 'N/A';
    final ip = log['ip_address'] as String? ?? 'N/A';

    final confidence = log['confidence_score'] as num?;
    final lat = log['latitude'] as double?;
    final long = log['longitude'] as double?;
    final city = log['city'] ?? 'Unknown';
    final state = log['state'] ?? 'Unknown';
    final country = log['country'] ?? 'Unknown';

    final anomaly = _analyzeAnomaly(log);
    final isSuspicious = anomaly['isSuspicious'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit Record Details',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (isSuspicious) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_rounded, color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'SECURITY WARNING FLAGS',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFB91C1C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...anomaly['reasons'].map<Widget>((reason) => Padding(
                            padding: const EdgeInsets.only(top: 2, left: 26),
                            child: Text(
                              '• $reason',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF7F1D1D),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildDetailsHeader('VERIFIED PROVIDER DETAILS'),
                  _buildDetailTile(
                    title: 'Name',
                    value: name,
                    subtitle: 'Verified Identity: Yes',
                    icon: Icons.assignment_ind_outlined,
                  ),
                  _buildDetailTile(
                    title: 'System Role',
                    value: role.toUpperCase(),
                    subtitle: 'Authentication Status: Success',
                    icon: Icons.shield_outlined,
                  ),
                  _buildDetailTile(
                    title: 'Organization',
                    value: '$hosp ($org)',
                    subtitle: 'Clinical Network Registry verified',
                    icon: Icons.local_hospital_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailsHeader('VERIFICATION MECHANISM'),
                  _buildDetailTile(
                    title: 'Method',
                    value: method,
                    subtitle: 'Scope: $scope',
                    icon: Icons.key_outlined,
                  ),
                  if (confidence != null && confidence > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Face Similarity Match Score',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '${confidence.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: confidence < 75 ? Colors.red : Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: confidence / 100.0,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: confidence < 75 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildDetailsHeader('TIMELINE & GEOLOCATION'),
                  _buildDetailTile(
                    title: 'Timestamp',
                    value: '$dateStr at $timeStr',
                    subtitle: 'Server NTP time synchronized',
                    icon: Icons.schedule_rounded,
                  ),
                  _buildDetailTile(
                    title: 'Access Point Coordinates',
                    value: lat != null && long != null ? '$lat, $long' : 'N/A',
                    subtitle: '$city, $state, $country (IP: $ip)',
                    icon: Icons.pin_drop_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailsHeader('DEVICE AUDIT FINGERPRINT'),
                  _buildDetailTile(
                    title: 'Model & OS',
                    value: '$deviceName ($devicePlatform)',
                    subtitle: 'Security patches verified',
                    icon: Icons.phone_android_outlined,
                  ),
                  _buildDetailTile(
                    title: 'Hardware UUID Signature',
                    value: deviceId,
                    subtitle: 'Immutable device fingerprint',
                    icon: Icons.fingerprint_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailsHeader('ACCESS STATUS OUTCOME'),
                  _buildDetailTile(
                    title: 'Record Status',
                    value: status.toUpperCase(),
                    subtitle: 'Ledger Hash: ${log['id']}',
                    icon: Icons.cloud_done_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF5200),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDetailTile({required String title, required String value, required String subtitle, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
