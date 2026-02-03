import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile.dart';
import '../../../patient/models/vital.dart';
import '../../providers/doctor_patient_provider.dart';
import '../../../../routing/route_names.dart';

class PatientRecordScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const PatientRecordScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientData = ref.watch(doctorPatientDataProvider(patientId));
    final vitals = ref.watch(doctorPatientVitalsProvider(patientId));
    final conditions = ref.watch(doctorPatientConditionsProvider(patientId));
    final prescriptions = ref.watch(doctorPatientPrescriptionsProvider(patientId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(patientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () {
              // Navigate to chat with patient
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Patient Header Info
            patientData.when(
              data: (data) => _buildHeader(data),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Recent Vitals'),
                  const SizedBox(height: 12),
                  vitals.when(
                    data: (v) => _buildVitalsGrid(v),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, __) => Text('Error: $e'),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Medical Conditions'),
                  const SizedBox(height: 12),
                  conditions.when(
                    data: (c) => _buildConditionsList(c),
                    loading: () => const SizedBox.shrink(),
                    error: (e, __) => Text('Error: $e'),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Prescription History'),
                      TextButton(
                        onPressed: () {
                          // View all history
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  prescriptions.when(
                    data: (p) => _buildPrescriptionList(p),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, __) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(RouteNames.doctorNewPrescription, extra: {
            'patientId': patientId,
            'patientName': patientName,
          });
        },
        backgroundColor: AppColors.doctor,
        icon: const Icon(Icons.add),
        label: const Text('Issue Prescription'),
      ),
    );
  }

  Widget _buildHeader(dynamic patient) {
    if (patient == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.softPrimary, size: 40),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blood Type: ${patient.bloodType ?? "N/A"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Age: ${_calculateAge(patient.dateOfBirth)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsGrid(List<Vital> vitals) {
    if (vitals.isEmpty) return _buildEmptyCard('No vitals recorded');

    // Get latest of each type
    final latestVitals = <String, Vital>{};
    for (var v in vitals) {
      if (!latestVitals.containsKey(v.type)) {
        latestVitals[v.type] = v;
      }
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: latestVitals.values.map((v) => _buildVitalCard(v)).toList(),
    );
  }

  Widget _buildVitalCard(Vital vital) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(vital.type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('LOCKED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              const SizedBox(width: 4),
              Text(vital.unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsList(List<dynamic> conditions) {
    if (conditions.isEmpty) return _buildEmptyCard('No conditions listed');
    return Column(
      children: conditions.map((c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 20),
            const SizedBox(width: 12),
            Text(c.conditionType, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPrescriptionList(List<dynamic> prescriptions) {
    if (prescriptions.isEmpty) return _buildEmptyCard('No history found');
    return Column(
      children: prescriptions.take(3).map((p) => ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(p.diagnosis),
        subtitle: Text(DateFormat('MMM dd, yyyy').format(p.createdAt!)),
        trailing: const Icon(Icons.history),
        onTap: () {},
      )).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.grey))),
    );
  }

  String _calculateAge(DateTime? dob) {
    if (dob == null) return 'N/A';
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.toString();
  }
}
