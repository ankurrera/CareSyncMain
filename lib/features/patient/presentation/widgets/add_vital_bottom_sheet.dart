import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/vital.dart';
import '../../providers/vitals_provider.dart';

class AddVitalBottomSheet extends ConsumerStatefulWidget {
  const AddVitalBottomSheet({super.key});

  @override
  ConsumerState<AddVitalBottomSheet> createState() => _AddVitalBottomSheetState();
}

class _AddVitalBottomSheetState extends ConsumerState<AddVitalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  VitalType _selectedType = VitalType.bloodPressure;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(patientVitalsProvider.notifier).addVital(
        type: _selectedType,
        value: _valueController.text,
        unit: _selectedType.unit,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save vital: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log Health Vital',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Type Selection
            DropdownButtonFormField<VitalType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Vital Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: VitalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 16),
            // Value Input
            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Value',
                hintText: _selectedType == VitalType.bloodPressure ? '120/80' : '75.5',
                suffixText: _selectedType.unit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Please enter a value' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.softPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
