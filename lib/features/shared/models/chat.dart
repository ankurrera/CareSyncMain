import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_profile.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class ChatRoom with _$ChatRoom {
  const factory ChatRoom({
    required String id,
    @JsonKey(name: 'patient_id') required String patientId,
    @JsonKey(name: 'doctor_id') required String doctorId,
    @JsonKey(name: 'last_message_at') required DateTime lastMessageAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // Joined data
    UserProfile? patient,
    UserProfile? doctor,
    Message? lastMessage,
  }) = _ChatRoom;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => _$ChatRoomFromJson(json);
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'room_id') required String roomId,
    @JsonKey(name: 'sender_id') required String senderId,
    required String content, // Encrypted Base64 string
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
