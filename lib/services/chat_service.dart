import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/shared/models/chat.dart';
import 'supabase_service.dart';
import 'encryption_service.dart';

class ChatService {
  ChatService(this._supabase, this._encryption);

  final SupabaseService _supabase;
  final EncryptionService _encryption;

  Future<List<ChatRoom>> getChatRooms() async {
    final userId = _supabase.currentUserId;
    if (userId == null) return [];

    final response = await _supabase.client
        .from('chat_rooms')
        .select('*, patient:profiles!patient_id(*), doctor:profiles!doctor_id(*)')
        .or('patient_id.eq.$userId,doctor_id.eq.$userId')
        .order('last_message_at', ascending: false);

    return (response as List).map((json) => ChatRoom.fromJson(json)).toList();
  }

  Future<List<Message>> getMessages(String roomId) async {
    final response = await _supabase.client
        .from('messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => Message.fromJson(json)).toList();
  }

  Future<void> sendMessage(String roomId, String content, {String? attachmentUrl}) async {
    final userId = _supabase.currentUserId;
    if (userId == null) return;

    // Encrypt the message content
    final encryptedContent = await _encryption.encryptMedicalRecord(
      data: content,
      biometricReason: 'Authenticate to send a secure message',
    );

    await _supabase.client.from('messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'content': encryptedContent,
      'is_read': false,
      'attachment_url': attachmentUrl,
    });

    // Update last_message_at in chat_room
    await _supabase.client
        .from('chat_rooms')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', roomId);
  }

  Future<void> markMessagesAsRead(String roomId, String currentUserId) async {
    await _supabase.client
        .from('messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
  }

  Future<String?> uploadChatAttachment(String roomId, String filePath, Uint8List fileBytes) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final path = 'rooms/$roomId/$fileName';
      
      await _supabase.client.storage
          .from('chat_attachments')
          .uploadBinary(path, fileBytes);
          
      return _supabase.client.storage.from('chat_attachments').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeToMessages(String roomId) {
    late StreamController<List<Map<String, dynamic>>> controller;
    dynamic channel; // RealtimeChannel

    Future<void> _fetchAndEmit() async {
      try {
        final response = await _supabase.client
            .from('messages')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: true);
        if (!controller.isClosed) {
          controller.add(List<Map<String, dynamic>>.from(response as List));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () async {
        // 1. Emit current messages immediately
        await _fetchAndEmit();

        // 2. Subscribe to real-time ALL events via Postgres Changes (so updates/reads sync instantly)
        channel = _supabase.client
            .channel('room-$roomId-messages')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'room_id',
                value: roomId,
              ),
              callback: (_) => _fetchAndEmit(),
            )
            .subscribe();
      },
      onCancel: () {
        channel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<ChatRoom> getOrCreateRoom(String otherId) async {
    final userId = _supabase.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Determine roles for unique constraint
    final userProfile = await _supabase.getProfile();
    final isPatient = userProfile?['role'] == 'patient';
    
    final patientId = isPatient ? userId : otherId;
    final doctorId = isPatient ? otherId : userId;

    final existing = await _supabase.client
        .from('chat_rooms')
        .select()
        .eq('patient_id', patientId)
        .eq('doctor_id', doctorId)
        .maybeSingle();

    if (existing != null) {
      return ChatRoom.fromJson(existing);
    }

    final created = await _supabase.client
        .from('chat_rooms')
        .insert({
          'patient_id': patientId,
          'doctor_id': doctorId,
        })
        .select()
        .single();

    return ChatRoom.fromJson(created);
  }
}

final chatServiceProvider = Provider((ref) {
  return ChatService(
    SupabaseService.instance,
    EncryptionService.instance,
  );
});
