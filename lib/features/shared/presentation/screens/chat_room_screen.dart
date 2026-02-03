import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/encryption_service.dart';
import '../../models/chat.dart';
import '../../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String otherName;
  const ChatRoomScreen({super.key, required this.roomId, required this.otherName});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final content = _messageController.text.trim();
    _messageController.clear();
    
    try {
      await ref.read(chatControllerProvider.notifier).sendMessage(widget.roomId, content);
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(roomMessagesProvider(widget.roomId));
    final currentUserId = SupabaseService.instance.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Secure End-to-End Chat', style: TextStyle(fontSize: 11, color: Colors.green)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesStream.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Start your secure conversation'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMe = message.senderId == currentUserId;
                    return _ChatBubble(message: message, isMe: isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a secure message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.softBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.softPrimary,
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  const _ChatBubble({required this.message, required this.isMe});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  String? _decryptedContent;
  bool _isDecrypting = false;

  Future<void> _decrypt() async {
    setState(() => _isDecrypting = true);
    try {
      final decrypted = await EncryptionService.instance.decryptMedicalRecord(
        encryptedData: widget.message.content,
        biometricReason: 'Authenticate to read this message',
      );
      setState(() {
        _decryptedContent = decrypted;
        _isDecrypting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isDecrypting = false);
        // Silently fails if biometrics canceled, keeps locked state
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: widget.isMe ? AppColors.softPrimary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 0),
            bottomRight: Radius.circular(widget.isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_decryptedContent != null)
              Text(
                _decryptedContent!,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : AppColors.textMain,
                  fontSize: 15,
                ),
              )
            else if (_isDecrypting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              )
            else
              TextButton.icon(
                onPressed: _decrypt,
                icon: Icon(
                  Icons.lock_rounded, 
                  size: 14, 
                  color: widget.isMe ? Colors.white70 : AppColors.softPrimary.withValues(alpha: 0.7)
                ),
                label: Text(
                  'Decrypt Message',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isMe ? Colors.white70 : AppColors.softPrimary,
                  ),
                ),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat.jm().format(widget.message.createdAt),
              style: TextStyle(
                fontSize: 9,
                color: widget.isMe ? Colors.white60 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
