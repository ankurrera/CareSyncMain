import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/prescription_input_models.dart';

/// Reusable medication card for entering medication details
class MedicationCardWidget extends StatefulWidget {
  final int index;
  final VoidCallback onRemove;
  final Function(MedicationDetails) onChanged;
  final MedicationDetails? initialData;

  const MedicationCardWidget({
    super.key,
    required this.index,
    required this.onRemove,
    required this.onChanged,
    this.initialData,
  });

  @override
  State<MedicationCardWidget> createState() => _MedicationCardWidgetState();
}

class _MedicationCardWidgetState extends State<MedicationCardWidget> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _durationController;
  late final TextEditingController _quantityController;
  late final TextEditingController _instructionsController;

  String? _selectedFrequency;
  MedicineType? _medicineType;
  RouteOfAdministration? _route;
  FoodTiming? _foodTiming;

  static const Map<String, int> frequencyMap = {
    "Once a day": 1,
    "Twice a day": 2,
    "Thrice a day": 3,
    "Four times a day": 4,
    "Every 8 hours": 3,
    "Every 12 hours": 2,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData?.medicineName,
    );
    _dosageController = TextEditingController(text: widget.initialData?.dosage);
    final initialFrequency = widget.initialData?.frequency;
    _selectedFrequency =
        (initialFrequency != null && frequencyMap.containsKey(initialFrequency))
            ? initialFrequency
            : null;
    _durationController = TextEditingController(
      text: widget.initialData?.duration,
    );
    final initialQuantity = widget.initialData?.quantity;
    _quantityController = TextEditingController(
      text:
          initialQuantity != null && initialQuantity > 0
              ? initialQuantity.toString()
              : '',
    );
    _instructionsController = TextEditingController(
      text: widget.initialData?.instructions,
    );
    _medicineType = widget.initialData?.medicineType;
    _route = widget.initialData?.route;
    _foodTiming = widget.initialData?.foodTiming;

    _nameController.addListener(_notifyChange);
    _dosageController.addListener(_notifyChange);
    _durationController.addListener(_calculateQuantity);
    _quantityController.addListener(_notifyChange);
    _instructionsController.addListener(_notifyChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _quantityController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _calculateQuantity() {
    if (_durationController.text.isEmpty || _selectedFrequency == null) {
      _quantityController.text = '';
      return;
    }

    final int? duration = int.tryParse(_durationController.text.trim());
    if (duration == null) {
      _quantityController.text = '';
      return;
    }

    final int frequencyPerDay = frequencyMap[_selectedFrequency] ?? 1;
    final int calculatedQuantity = duration * frequencyPerDay;

    _quantityController.text = calculatedQuantity.toString();
  }

  void _notifyChange() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;

    final medication = MedicationDetails(
      id: widget.initialData?.id,
      medicineName: _nameController.text,
      dosage: _dosageController.text,
      frequency: _selectedFrequency ?? '',
      duration: _durationController.text,
      quantity: quantity,
      medicineType: _medicineType,
      route: _route,
      foodTiming: _foodTiming,
      instructions:
          _instructionsController.text.isNotEmpty
              ? _instructionsController.text
              : null,
    );

    widget.onChanged(medication);
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? label,
    Widget? suffix,
  }) {
    final t = context.tokens;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: t.textSecondary,
      ),
      hintText: hint,
      hintStyle: TextStyle(color: t.textSecondary, fontSize: 12),
      filled: true,
      fillColor: t.scaffold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      suffixIcon: suffix,
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: t.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Medication',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Iconsax.trash, size: 14),
                  style: IconButton.styleFrom(
                    foregroundColor: t.error,
                    backgroundColor: t.error.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medicine Name
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                hint: 'e.g., Paracetamol',
                label: 'Medicine Name *',
                suffix: Icon(Iconsax.box, size: 16, color: t.textSecondary),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Medicine name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Dosage and Frequency Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dosageController,
                    decoration: _inputDecoration(
                      hint: 'e.g., 500mg',
                      label: 'Dosage *',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFrequency,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      hint: 'Select',
                      label: 'Frequency *',
                    ),
                    items:
                        frequencyMap.keys.map((frequency) {
                          return DropdownMenuItem(
                            value: frequency,
                            child: Text(
                              frequency,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedFrequency = value);
                      _calculateQuantity();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration and Quantity Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: _inputDecoration(
                      hint: 'e.g., 7',
                      label: 'Duration (Days) *',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label:
                        _quantityController.text.isNotEmpty
                            ? 'Quantity ${_quantityController.text}'
                            : 'Quantity',
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: _inputDecoration(
                        hint: 'Manual override',
                        label: 'Quantity *',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Medicine Type
            DropdownButtonFormField<MedicineType>(
              initialValue: _medicineType,
              isExpanded: true,
              decoration: _inputDecoration(
                hint: 'Select type',
                label: 'Medicine Type *',
              ),
              items:
                  MedicineType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.displayName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => _medicineType = value);
                _notifyChange();
              },
              validator: (value) {
                if (value == null) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Route and Food Timing Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<RouteOfAdministration>(
                    initialValue: _route,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      hint: 'Select',
                      label: 'Route *',
                    ),
                    items:
                        RouteOfAdministration.values.map((route) {
                          return DropdownMenuItem(
                            value: route,
                            child: Text(
                              route.displayName,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _route = value);
                      _notifyChange();
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<FoodTiming>(
                    initialValue: _foodTiming,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      hint: 'Select',
                      label: 'Food Timing *',
                    ),
                    items:
                        FoodTiming.values.map((timing) {
                          return DropdownMenuItem(
                            value: timing,
                            child: Text(
                              timing.displayName,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _foodTiming = value);
                      _notifyChange();
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Instructions
            TextFormField(
              controller: _instructionsController,
              decoration: _inputDecoration(
                hint: 'e.g., Take after meals with water',
                label: 'Instructions',
              ),
              maxLines: 2,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final lowerValue = value.trim().toLowerCase();
                  if (lowerValue == 'mm' ||
                      lowerValue == 'mmm' ||
                      lowerValue == 'n/a' ||
                      lowerValue == 'na' ||
                      lowerValue.startsWith('take food mmm') ||
                      lowerValue.startsWith('take after food mmm') ||
                      lowerValue == 'test' ||
                      lowerValue == 'placeholder') {
                    return 'Please remove placeholder text or leave empty';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
