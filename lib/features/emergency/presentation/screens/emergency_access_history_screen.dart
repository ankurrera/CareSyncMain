import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/emergency_audit_service.dart';
import '../../../../routing/screen_titles.dart';

/// Provider to fetch immutable audit logs from database
final emergencyLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  if (currentUser == null) return [];

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
    if (country != 'Unknown' &&
        country != 'United States' &&
        country != 'US' &&
        country != 'India') {
      issues.add('Access origin flags unexpected territory ($country)');
    }

    return {'isSuspicious': issues.isNotEmpty, 'reasons': issues};
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final logsAsync = ref.watch(emergencyLogsProvider);

    return CSScaffold(
      title: ScreenTitles.patientEmergencyAudit,
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(emergencyLogsProvider),
          icon: Icon(Iconsax.refresh, color: t.textSecondary, size: 18),
        ),
      ],
      body: logsAsync.when(
        data: (logs) {
          final filteredLogs =
              logs.where((log) {
                final search = _searchController.text.trim().toLowerCase();
                if (search.isNotEmpty) {
                  final docName =
                      (log['accessed_by_name'] as String? ?? '').toLowerCase();
                  final hosp =
                      (log['hospital_name'] as String? ?? '').toLowerCase();
                  final role =
                      (log['accessed_by_role'] as String? ?? '').toLowerCase();
                  final uid =
                      (log['accessed_by_user_id'] as String? ?? '')
                          .toLowerCase();

                  if (!docName.contains(search) &&
                      !hosp.contains(search) &&
                      !role.contains(search) &&
                      !uid.contains(search)) {
                    return false;
                  }
                }

                if (_selectedMethod != 'All' &&
                    log['authentication_method'] != _selectedMethod) {
                  return false;
                }

                if (_selectedRole != 'All' &&
                    log['accessed_by_role'] != _selectedRole.toLowerCase()) {
                  return false;
                }

                if (_selectedStatus != 'All' &&
                    log['access_status'] != _selectedStatus) {
                  return false;
                }

                if (_selectedReason != 'All' &&
                    log['reason_for_access'] != _selectedReason) {
                  return false;
                }

                return true;
              }).toList();

          return Column(
            children: [
              _buildAnalyticsSection(logs),
              _buildSearchFilterSection(),
              Expanded(
                child:
                    filteredLogs.isEmpty
                        ? _buildEmptyState()
                        : _buildTimelineList(filteredLogs),
              ),
            ],
          );
        },
        loading:
            () => Center(
              child: CircularProgressIndicator(
                color: t.accent,
                strokeWidth: 2.5,
              ),
            ),
        error:
            (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to retrieve audit log ledger: $err',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.error, fontWeight: FontWeight.w700),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildAnalyticsSection(List<Map<String, dynamic>> logs) {
    final t = context.tokens;
    int totalAccesses = logs.length;
    int failedCount =
        logs
            .where(
              (l) =>
                  l['access_status'] == 'Failed' ||
                  l['access_status'] == 'Denied',
            )
            .length;
    int suspiciousCount =
        logs.where((l) => _analyzeAnomaly(l)['isSuspicious'] == true).length;
    int qrCount =
        logs.where((l) => l['authentication_method'] == 'QR Code').length;
    int faceCount =
        logs
            .where((l) => l['authentication_method'] == 'Face Recognition')
            .length;
    int overrideCount =
        logs
            .where(
              (l) => l['authentication_method'] == 'Manual Emergency Override',
            )
            .length;

    return SizedBox(
      height: 96,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildStatCard(
              'Total Accesses',
              totalAccesses.toString(),
              '30 Days',
              t.accent,
              Iconsax.security,
            ),
            _buildStatCard(
              'Failed Attempts',
              failedCount.toString(),
              'Denied access',
              t.error,
              Iconsax.warning_2,
            ),
            _buildStatCard(
              'Suspicious Alerts',
              suspiciousCount.toString(),
              'Anomalies flagged',
              t.accent,
              Iconsax.shield_search,
            ),
            _buildStatCard(
              'QR Scans',
              qrCount.toString(),
              'Quick lookup',
              t.accent,
              Iconsax.scan,
            ),
            _buildStatCard(
              'Biometrics Match',
              faceCount.toString(),
              'Face recognition',
              t.accent,
              Iconsax.frame_1,
            ),
            _buildStatCard(
              'Emergency Override',
              overrideCount.toString(),
              'Manual override',
              t.accent,
              Iconsax.lock_slash,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    final t = context.tokens;
    return Container(
      width: 144,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.textSecondary,
                  ),
                ),
              ),
              Icon(icon, size: 13, color: color),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterSection() {
    final t = context.tokens;
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
                    color: t.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.divider),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    cursorColor: t.accent,
                    decoration: InputDecoration(
                      hintText: 'Search by provider, clinic, role...',
                      hintStyle: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Iconsax.search_normal_1,
                        size: 16,
                        color: t.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap:
                    () =>
                        setState(() => _isFilterExpanded = !_isFilterExpanded),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _isFilterExpanded ? t.accent : t.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isFilterExpanded ? t.accent : t.divider,
                    ),
                  ),
                  child: Icon(
                    Iconsax.filter,
                    size: 16,
                    color: _isFilterExpanded ? t.accentOn : t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (_isFilterExpanded) ...[
            const SizedBox(height: 10),
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              borderSide: BorderSide(color: t.divider),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Auth Method',
                          _selectedMethod,
                          [
                            'All',
                            'Face Recognition',
                            'QR Code',
                            'Manual Emergency Override',
                          ],
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
                          [
                            'All',
                            'Emergency Treatment',
                            'Trauma',
                            'Cardiac Arrest',
                            'Stroke',
                            'Unknown Patient',
                          ],
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

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: t.monoMeta.copyWith(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: t.scaffold,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: t.textSecondary),
              dropdownColor: t.card,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              items:
                  items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineList(List<Map<String, dynamic>> logs) {
    final t = context.tokens;
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
              style: t.monoSectionHeader.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: t.accent,
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
    final t = context.tokens;
    final method = log['authentication_method'] as String? ?? 'QR Code';
    final name = log['accessed_by_name'] as String? ?? 'Unknown Provider';
    final role = log['accessed_by_role'] as String? ?? 'unknown';
    final hosp = log['hospital_name'] as String? ?? 'CareSync Network';
    final status = log['access_status'] as String? ?? 'Success';
    final tsStr = log['timestamp'] as String?;
    final ts = tsStr != null ? DateTime.parse(tsStr) : DateTime.now();
    final timeStr = DateFormat('h:mm a').format(ts);
    final location = [
      log['city'],
      log['state'],
    ].where((e) => e != null && e != 'Unknown').join(', ');

    final anomaly = _analyzeAnomaly(log);
    final isSuspicious = anomaly['isSuspicious'] == true;

    final statusColor = status == 'Success' ? t.accent : t.error;
    final statusIcon =
        status == 'Success'
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded;

    IconData methodIcon;
    if (method == 'Face Recognition') {
      methodIcon = Iconsax.frame_1;
    } else if (method == 'QR Code') {
      methodIcon = Iconsax.scan;
    } else {
      methodIcon = Iconsax.lock_slash;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(
          color: isSuspicious ? t.error.withValues(alpha: 0.3) : t.divider,
        ),
        padding: const EdgeInsets.all(14),
        onTap: () => _showAuditDetails(log),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  isSuspicious ? t.error.withValues(alpha: 0.1) : t.scaffold,
              child: Icon(
                methodIcon,
                size: 15,
                color: isSuspicious ? t.error : t.textSecondary,
              ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${role.toUpperCase()} • $hosp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                      color: t.textSecondary,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.location,
                          size: 10.5,
                          color: t.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 10,
                            color: t.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isSuspicious) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        anomaly['reasons'][0],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.error,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildEmptyState() {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.card,
                shape: BoxShape.circle,
                border: Border.all(color: t.divider, width: 2),
              ),
              child: Icon(
                Iconsax.shield_security,
                size: 44,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Audit Logs Found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: t.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All emergency accesses will be immutably recorded here. Currently, no access history exists for your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    showAppSheet<void>(
      context,
      showHandle: false,
      builder: (ctx) {
        final t = ctx.tokens;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Audit Record Details', style: t.sheetTitle),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: t.textSecondary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: t.scaffold,
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.divider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (isSuspicious) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: t.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Iconsax.warning_2,
                                  color: t.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SECURITY WARNING FLAGS',
                                  style: TextStyle(
                                    color: t.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...anomaly['reasons'].map<Widget>(
                              (reason) => Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  left: 26,
                                ),
                                child: Text(
                                  '• $reason',
                                  style: TextStyle(
                                    color: t.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
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
                      icon: Iconsax.profile_tick,
                    ),
                    _buildDetailTile(
                      title: 'System Role',
                      value: role.toUpperCase(),
                      subtitle: 'Authentication Status: Success',
                      icon: Iconsax.shield_tick,
                    ),
                    _buildDetailTile(
                      title: 'Organization',
                      value: '$hosp ($org)',
                      subtitle: 'Clinical Network Registry verified',
                      icon: Iconsax.hospital,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailsHeader('VERIFICATION MECHANISM'),
                    _buildDetailTile(
                      title: 'Method',
                      value: method,
                      subtitle: 'Scope: $scope',
                      icon: Iconsax.key,
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: t.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${confidence.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: confidence < 75 ? t.error : t.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: confidence / 100.0,
                                minHeight: 6,
                                backgroundColor: t.divider,
                                color: confidence < 75 ? t.error : t.accent,
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
                      icon: Iconsax.clock,
                    ),
                    _buildDetailTile(
                      title: 'Access Point Coordinates',
                      value:
                          lat != null && long != null ? '$lat, $long' : 'N/A',
                      subtitle: '$city, $state, $country (IP: $ip)',
                      icon: Iconsax.location,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailsHeader('DEVICE AUDIT FINGERPRINT'),
                    _buildDetailTile(
                      title: 'Model & OS',
                      value: '$deviceName ($devicePlatform)',
                      subtitle: 'Security patches verified',
                      icon: Iconsax.mobile,
                    ),
                    _buildDetailTile(
                      title: 'Hardware UUID Signature',
                      value: deviceId,
                      subtitle: 'Immutable device fingerprint',
                      icon: Iconsax.finger_scan,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailsHeader('ACCESS STATUS OUTCOME'),
                    _buildDetailTile(
                      title: 'Record Status',
                      value: status.toUpperCase(),
                      subtitle: 'Ledger Hash: ${log['id']}',
                      icon: Iconsax.cloud_change,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsHeader(String title) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: t.monoSectionHeader.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: t.accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: t.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: t.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
