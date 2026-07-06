import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';


import '../../../../services/supabase_service.dart';
import '../../providers/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _emailController = TextEditingController();
  bool _isCreatingChat = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _startNewChat() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() => _isCreatingChat = true);

    try {
      final currentUserId = SupabaseService.instance.currentUserId;
      if (currentUserId == null) throw Exception('Not authenticated');

      // 1. Query other profile by email via secure RPC (case-insensitive, bypasses RLS)
      final List<dynamic> rpcResult = await SupabaseService.instance.client
          .rpc('find_profile_by_email', params: {'target_email': email});

      final otherProfile = rpcResult.isNotEmpty
          ? rpcResult.first as Map<String, dynamic>
          : null;

      if (otherProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No account found with this email.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final otherUserId = otherProfile['id'] as String;
      final otherName = otherProfile['full_name'] as String? ?? 'Secure User';
      final otherRole = otherProfile['role'] as String?;

      if (otherUserId == currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You cannot start a secure conversation with yourself.'),
              backgroundColor: Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Fetch current profile to check role compatibility
      final currentProfile = await SupabaseService.instance.getProfile();
      final currentRole = currentProfile?['role'] as String?;

      // Validate roles (must be complementary: doctor & patient)
      if (currentRole == otherRole) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentRole == 'doctor'
                    ? 'As a doctor, you can only message patient accounts.'
                    : 'As a patient, you can only message doctor accounts.',
              ),
              backgroundColor: const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 3. Create or fetch existing room
      final room = await ref.read(chatControllerProvider.notifier).getOrCreateRoom(otherUserId);

      // Invalidate room list cache
      ref.invalidate(chatRoomsProvider);

      if (mounted) {
        _emailController.clear();
        Navigator.of(context).pop(); // Close dialog
        context.push('/chat/${room.id}', extra: otherName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting secure conversation: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingChat = false);
      }
    }
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Start Secure Message',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the email address of the doctor or patient to start a secure, end-to-end encrypted chat.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'user@caresync.com',
                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Iconsax.sms, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _emailController.clear();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isCreatingChat
                      ? null
                      : () async {
                          setDialogState(() => _isCreatingChat = true);
                          await _startNewChat();
                          setDialogState(() => _isCreatingChat = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isCreatingChat
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Start Chat',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final currentUserId = SupabaseService.instance.currentUserId;

    // Premium styling colors
    const Color kBgColor = Color(0xFFF8FAFC);
    const Color kSurfaceColor = Color(0xFFFFFFFF);
    const Color kPrimaryColor = Color(0xFF0284C7);
    const Color kTextPrimary = Color(0xFF0F172A);
    const Color kTextSecondary = Color(0xFF475569);
    const Color kBorderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Messages',
          style: GoogleFonts.plusJakartaSans(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chatRoomsProvider),
        color: kPrimaryColor,
        child: chatRoomsAsync.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kSurfaceColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: kBorderColor),
                            ),
                            child: const Icon(
                              Iconsax.message_search,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No Messages Yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start a secure conversation by clicking the button below and entering the account email address.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: kTextSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              itemCount: rooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final room = rooms[index];
                final otherUser = room.patientId == currentUserId ? room.doctor : room.patient;
                final displayName = otherUser?.fullName ?? 'CareSync User';
                final timeStr = DateFormat('h:mm a').format(room.lastMessageAt);

                return Container(
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: kPrimaryColor.withOpacity(0.08),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: GoogleFonts.plusJakartaSans(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: kTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Tap to open secure chat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: kTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Iconsax.shield_security,
                          color: Color(0xFF10B981),
                          size: 14,
                        ),
                      ],
                    ),
                    onTap: () => context.push('/chat/${room.id}', extra: displayName),
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading chats: $err',
              style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 13),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewChatDialog,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Iconsax.message_add, size: 18),
        label: Text(
          'New Chat',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
