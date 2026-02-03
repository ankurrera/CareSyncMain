import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/supabase_service.dart';
import '../../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final currentUserId = SupabaseService.instance.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: chatRoomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(child: Text('No messages yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: rooms.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final otherUser = room.patientId == currentUserId ? room.doctor : room.patient;
              final displayName = otherUser?.fullName ?? 'HCP';
              final timeStr = DateFormat.jm().format(room.lastMessageAt);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowSoft.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.softPrimary.withValues(alpha: 0.1),
                    child: Text(
                      displayName[0],
                      style: const TextStyle(color: AppColors.softPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text('Tap to view secure telegram', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    timeStr,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () => context.push('/chat/${room.id}', extra: displayName),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
