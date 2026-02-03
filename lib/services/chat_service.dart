import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> sendMessage(String roomId, String content) async {
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
    });

    // Update last_message_at in chat_room
    await _supabase.client
        .from('chat_rooms')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', roomId);
  }

  Stream<List<Map<String, dynamic>>> subscribeToMessages(String roomId) {
    return _supabase.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
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
