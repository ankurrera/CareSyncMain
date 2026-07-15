import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../../routing/screen_titles.dart';

class PharmacistSearchScreen extends StatefulWidget {
  const PharmacistSearchScreen({super.key});

  @override
  State<PharmacistSearchScreen> createState() => _PharmacistSearchScreenState();
}

class _PharmacistSearchScreenState extends State<PharmacistSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  int _page = 0;
  final int _pageSize = 15;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePatients();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
      setState(() {
        _searchResults = [];
        _page = 0;
        _hasMore = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _page = 0;
      _hasMore = true;
      _searchResults = [];
    });

    try {
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or(
            'email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%',
          )
          .range(0, _pageSize - 1);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _hasMore = response.length >= _pageSize;
      });
    } catch (e) {
      AppLogger.warning(
        'Error searching patients',
        category: LogCategory.database,
        error: e,
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMorePatients() async {
    if (_isLoadingMore || !_hasMore) return;
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final from = nextPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or(
            'email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%',
          )
          .range(from, to);

      setState(() {
        _page = nextPage;
        _searchResults.addAll(List<Map<String, dynamic>>.from(response));
        _hasMore = response.length >= _pageSize;
      });
    } catch (e) {
      AppLogger.warning(
        'Error loading more patients',
        category: LogCategory.database,
        error: e,
      );
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _selectPatient(Map<String, dynamic> profile) async {
    // Retrieve patient record to get their qr_code_id
    try {
      final patientRecord =
          await SupabaseService.instance.client
              .from('patients')
              .select('qr_code_id')
              .eq('user_id', profile['id'])
              .maybeSingle();

      if (!mounted) return;

      if (patientRecord == null || patientRecord['qr_code_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient record has no registered QR code ID'),
            backgroundColor: context.tokens.error,
          ),
        );
        return;
      }

      // Navigate to dispensing screen with patient's QR ID
      context.push(
        RouteNames.pharmacistDispense,
        extra: patientRecord['qr_code_id'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load patient: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CSScaffold(
      title: ScreenTitles.pharmacistSearch,
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Patients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter patient name, email, or phone number to load prescription list.',
              style: TextStyle(fontSize: 14, color: t.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              cursorColor: t.accent,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                hintStyle: TextStyle(
                  color: t.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 10),
                  child: Icon(
                    Iconsax.search_normal_1,
                    color: t.textSecondary,
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(Iconsax.close_circle),
                            color: t.textSecondary,
                            iconSize: 18,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          ),
                        )
                        : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                filled: true,
                fillColor: t.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child:
                  _isSearching
                      ? Center(
                        child: CircularProgressIndicator(color: t.accent),
                      )
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
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.people, size: 64, color: t.textSecondary),
          const SizedBox(height: 16),
          Text(
            _searchController.text.length < 2
                ? 'Type at least 2 characters to search'
                : 'No patients found',
            style: TextStyle(color: t.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final t = context.tokens;
    return ListView.separated(
      controller: _scrollController,
      itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            ),
          );
        }
        final profile = _searchResults[index];
        final email = profile['email'] as String? ?? 'No email';
        final phone = profile['phone'] as String? ?? 'No phone';

        return SquircleCard(
          radius: AppSpacing.squircleGrouped,
          borderSide: BorderSide(color: t.divider),
          padding: EdgeInsets.zero,
          onTap: () => _selectPatient(profile),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: t.tint,
              child: Icon(Iconsax.user, color: t.accent),
            ),
            title: Text(
              profile['full_name'] as String? ?? 'Unknown Patient',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            subtitle: Text(
              '$email\n$phone',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
            trailing: Icon(Iconsax.arrow_right_3, color: t.textSecondary),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
