import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/chat.dart';
import '../../../services/chat_service.dart';
import '../../../services/supabase_service.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatRooms extends _$ChatRooms {
  @override
  FutureOr<List<ChatRoom>> build() async {
    return ref.read(chatServiceProvider).getChatRooms();
  }

  void refresh() => ref.invalidateSelf();
}

@riverpod
Stream<List<Message>> roomMessages(RoomMessagesRef ref, String roomId) {
  final chatService = ref.read(chatServiceProvider);
  return chatService.subscribeToMessages(roomId).map((list) {
    return list.map((json) => Message.fromJson(json)).toList();
  });
}

@riverpod
class ChatController extends _$ChatController {
  @override
  FutureOr<void> build() {}

  Future<void> sendMessage(String roomId, String content, {String? attachmentUrl}) async {
    await ref.read(chatServiceProvider).sendMessage(roomId, content, attachmentUrl: attachmentUrl);
  }

  Future<void> markMessagesAsRead(String roomId) async {
    final currentUserId = SupabaseService.instance.currentUserId;
    if (currentUserId == null) return;
    await ref.read(chatServiceProvider).markMessagesAsRead(roomId, currentUserId);
  }

  Future<String?> uploadChatAttachment(String roomId, String filePath, Uint8List fileBytes) async {
    return ref.read(chatServiceProvider).uploadChatAttachment(roomId, filePath, fileBytes);
  }

  Future<ChatRoom> getOrCreateRoom(String otherId) async {
    return ref.read(chatServiceProvider).getOrCreateRoom(otherId);
  }
}
