import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../services/supabase_service.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../models/prescription.dart';
import '../../providers/patient_provider.dart';
import '../../../../routing/screen_titles.dart';
import '../widgets/prescription_card.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  final _scrollController = ScrollController();
  List<Prescription> _prescriptionsList = [];
  int _page = 0;
  final int _pageSize = 15;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadNextPage(isRefresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNextPage({bool isRefresh = false}) async {
    if (_isLoading || (!_hasMore && !isRefresh)) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final nextPage = isRefresh ? 0 : _page + 1;
      final patientData = await ref.read(patientDataProvider.future);
      if (patientData != null) {
        final data = await SupabaseService.instance.getPatientPrescriptions(
          patientData.id,
          limit: _pageSize,
          offset: nextPage * _pageSize,
        );
        final list = data.map((json) => Prescription.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            if (isRefresh) {
              _prescriptionsList = list;
            } else {
              _prescriptionsList.addAll(list);
            }
            _page = nextPage;
            _hasMore = list.length >= _pageSize;
          });
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Error loading paginated prescriptions',
        category: LogCategory.database,
        error: e,
      );
      if (mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget bodyWidget;
    if (_prescriptionsList.isEmpty && _isLoading) {
      bodyWidget = Center(child: CircularProgressIndicator(color: t.accent));
    } else if (_hasError && _prescriptionsList.isEmpty) {
      bodyWidget = _buildErrorState(context);
    } else if (_prescriptionsList.isEmpty) {
      bodyWidget = _buildEmptyState(context);
    } else {
      bodyWidget = RefreshIndicator(
        onRefresh: () => _loadNextPage(isRefresh: true),
        color: t.accent,
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: _prescriptionsList.length + (_isLoading ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == _prescriptionsList.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                ),
              );
            }
            return PrescriptionCard(prescription: _prescriptionsList[index]);
          },
        ),
      );
    }

    return CSScaffold(
      title: ScreenTitles.patientPrescriptions,
      actions: [
        IconButton(
          icon: Icon(Iconsax.add_circle, size: 22, color: t.accent),
          onPressed: () => context.push(RouteNames.patientAddPrescription),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.patientAddPrescription),
        icon: const Icon(Iconsax.add, size: 20),
        label: const Text(
          'Add New',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        backgroundColor: t.accent,
        foregroundColor: t.accentOn,
        elevation: 0,
      ),
      body: bodyWidget,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.card,
                shape: BoxShape.circle,
                border: Border.all(color: t.divider),
              ),
              child: Icon(
                Iconsax.document_text,
                size: 40,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Prescriptions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first prescription to track your medications and medical history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 36, color: t.error),
          const SizedBox(height: 14),
          Text(
            'Failed to load data',
            style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _loadNextPage(isRefresh: true),
            child: Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700, color: t.accent),
            ),
          ),
        ],
      ),
    );
  }
}
