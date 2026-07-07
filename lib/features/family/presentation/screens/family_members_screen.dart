import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/family_provider.dart';

// ── Design tokens (matching CareSync visual system) ────────────────────────
const _kBg       = Color(0xFFFAFAFA);
const _kInk      = Color(0xFF121212);
const _kOrange   = Color(0xFFFF5200);
const _kSlate    = Color(0xFF64748B);
const _kBorder   = Color(0xFFE2E8F0);
const _kGreen    = Color(0xFF22C55E);
const _kRed      = Color(0xFFEF4444);

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  bool _isSending = false;

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isSending,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Close Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Family Member',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: _kInk,
                            fontSize: 18,
                          ),
                        ),
                        if (!_isSending)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: _kSlate),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'An invitation will be sent to their email to link their medical records.',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kSlate,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Field Label
                    Text(
                      'EMAIL ADDRESS',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: _kSlate,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'name@example.com',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: _kSlate.withValues(alpha: 0.4),
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(Iconsax.sms, color: _kSlate, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kOrange, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        fillColor: const Color(0xFFF8FAFC), // Slate 50
                        filled: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kInk),
                      enabled: !_isSending,
                    ),
                    const SizedBox(height: 18),

                    // Relationship Field Label
                    Text(
                      'RELATIONSHIP LABEL',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: _kSlate,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Mom, Child, Spouse',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: _kSlate.withValues(alpha: 0.4),
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(Iconsax.tag, color: _kSlate, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kOrange, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        fillColor: const Color(0xFFF8FAFC), // Slate 50
                        filled: true,
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kInk),
                      enabled: !_isSending,
                    ),
                    const SizedBox(height: 28),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!_isSending)
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.plusJakartaSans(
                                color: _kSlate,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSending
                              ? null
                              : () async {
                                  final email = emailController.text.trim();
                                  final label = labelController.text.trim();

                                  if (email.isEmpty || label.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Please fill all fields',
                                          style: GoogleFonts.plusJakartaSans(),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => _isSending = true);

                                  await ref
                                      .read(familyControllerProvider.notifier)
                                      .sendRequest(email, label);

                                  final state = ref.read(familyControllerProvider);

                                  if (context.mounted) {
                                    setState(() => _isSending = false);
                                    Navigator.pop(context);

                                    if (state.hasError) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            state.error.toString().replaceAll('Exception:', '').trim(),
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          backgroundColor: AppColors.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Request sent successfully!',
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          backgroundColor: AppColors.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kInk,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Send Invite',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Family & Dependents',
          style: GoogleFonts.plusJakartaSans(
            color: _kInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _kBorder, height: 1.0),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Iconsax.user_add, size: 20),
        label: Text(
          'Add Member',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyMembersProvider);
          ref.invalidate(incomingRequestsProvider);
          ref.invalidate(outgoingRequestsProvider);
          await Future.wait([
            ref.refresh(familyMembersProvider.future),
            ref.refresh(incomingRequestsProvider.future),
            ref.refresh(outgoingRequestsProvider.future),
          ]);
        },
        color: _kOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            color: _kBg,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Incoming Requests (Needs Action) ──
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7), // Amber 100
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
                          ),
                          child: Row(
                            children: [
                              const Icon(Iconsax.notification_status, color: Color(0xFFD97706)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You have ${requests.length} incoming request(s)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF92400E),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...requests.map((req) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.015),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _kOrange.withValues(alpha: 0.08),
                                    foregroundColor: _kOrange,
                                    child: Text(
                                      req.requester.fullName[0].toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req.requester.fullName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _kInk,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Wants to link as: ${req.label}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: _kSlate,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Iconsax.tick_circle5,
                                            color: _kGreen, size: 28),
                                        onPressed: () => ref
                                            .read(familyControllerProvider.notifier)
                                            .respondToRequest(req.linkId, true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Iconsax.close_circle5,
                                            color: _kRed, size: 28),
                                        onPressed: () => ref
                                            .read(familyControllerProvider.notifier)
                                            .respondToRequest(req.linkId, false),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: _kOrange),
                    ),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                // ── 2. Outgoing Requests (Pending Status) ──
                outgoingAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sent Requests',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...requests.map((req) => GestureDetector(
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    title: Text(
                                      'Cancel Request?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        color: _kInk,
                                      ),
                                    ),
                                    content: Text(
                                      'Do you want to cancel the invitation to ${req.profile.fullName}?',
                                      style: GoogleFonts.plusJakartaSans(color: _kSlate),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(
                                          'No',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: _kSlate,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(familyControllerProvider.notifier)
                                              .cancelRequest(req.linkId);
                                          Navigator.pop(ctx);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kRed,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Yes, Cancel',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _kBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.015),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
                                      child: const Icon(Iconsax.timer, color: _kSlate, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.profile.fullName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: _kInk,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Invitation sent to ${req.profile.email}',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: _kSlate,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED), // Orange 50
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFFFEDD5)), // Orange 100
                                      ),
                                      child: Text(
                                        'Pending',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFEA580C), // Orange 600
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── 3. Active Members (Synced Accounts) ──
                Text(
                  'Synced Accounts',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch to these profiles from the main screen.',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kSlate,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _kSlate.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Iconsax.people,
                                    size: 36, color: _kSlate.withValues(alpha: 0.8)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No family members linked yet',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _kInk,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Add Member" to invite someone.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: _kSlate,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundColor: _kOrange.withValues(alpha: 0.08),
                              foregroundColor: _kOrange,
                              backgroundImage: member.profile.avatarUrl != null
                                  ? NetworkImage(member.profile.avatarUrl!)
                                  : null,
                              child: member.profile.avatarUrl == null
                                  ? Text(
                                      member.profile.fullName[0].toUpperCase(),
                                      style:
                                          GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              member.profile.fullName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: _kInk,
                              ),
                            ),
                            subtitle: Text(
                              member.label.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: _kSlate,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _kOrange.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.arrow_swap, color: _kOrange, size: 16),
                            ),
                            onTap: () {
                              ref
                                  .read(familyControllerProvider.notifier)
                                  .switchAccount(member.profile.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: _kOrange),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: GoogleFonts.plusJakartaSans(color: _kRed),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}