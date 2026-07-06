import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/encryption_service.dart';
import '../../models/chat.dart';
import '../../providers/chat_provider.dart';

// ─── Tokens ──────────────────────────────────────────────────────────────────
const _bg        = Color(0xFFFFFFFF);
const _chatBg    = Color(0xFFF5F7FA);
const _sentBg    = Color(0xFF1A1A2E);   // deep navy
const _recvBg    = Color(0xFFFFFFFF);
const _border    = Color(0xFFECEEF2);
const _textDark  = Color(0xFF111827);
const _textMid   = Color(0xFF6B7280);
const _textLight = Color(0xFF9CA3AF);
const _accent    = Color(0xFF6366F1);   // indigo

TextStyle _font({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _textDark,
  double height = 1.4,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String otherName;
  const ChatRoomScreen({super.key, required this.roomId, required this.otherName});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _hasText = false;
  XFile? _selectedAttachment;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_updateHasTextState);
  }

  void _updateHasTextState() {
    final has = _ctrl.text.trim().isNotEmpty || _selectedAttachment != null;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateHasTextState);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedAttachment = image;
        });
        _updateHasTextState();
      }
    } catch (e) {
      debugPrint('Error picking attachment: $e');
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _selectedAttachment == null) return;
    if (_sending) return;

    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    
    // Clear fields immediately to feel fast
    _ctrl.clear();
    final attachmentToUpload = _selectedAttachment;
    setState(() {
      _selectedAttachment = null;
    });
    _updateHasTextState();

    try {
      String? attachmentUrl;
      if (attachmentToUpload != null) {
        final bytes = await attachmentToUpload.readAsBytes();
        attachmentUrl = await ref
            .read(chatControllerProvider.notifier)
            .uploadChatAttachment(widget.roomId, attachmentToUpload.name, bytes);
      }

      await ref.read(chatControllerProvider.notifier).sendMessage(
        widget.roomId,
        text.isEmpty ? '[Image Attachment]' : text,
        attachmentUrl: attachmentUrl,
      );

      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send message', style: _font(color: Colors.white)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(roomMessagesProvider(widget.roomId));
    final me     = SupabaseService.instance.currentUserId;
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _chatBg,
        appBar: _appBar(),
        body: Column(
          children: [
            Expanded(
              child: stream.when(
                data: (msgs) {
                  // Mark messages as read when loaded/updated
                  if (msgs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(chatControllerProvider.notifier).markMessagesAsRead(widget.roomId);
                    });
                  }

                  return msgs.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) {
                            final msg  = msgs[msgs.length - 1 - i];
                            final isMe = msg.senderId == me;
                            final showDate = i == msgs.length - 1 ||
                                !_sameDay(
                                  msgs[msgs.length - 1 - i].createdAt,
                                  msgs[msgs.length - 2 - i].createdAt,
                                );
                            final prevSame = i > 0 &&
                                msgs[msgs.length - i].senderId == msg.senderId;
                            final nextSame = i < msgs.length - 1 &&
                                msgs[msgs.length - 2 - i].senderId == msg.senderId;

                            return Column(
                              children: [
                                if (showDate) _dateSep(msg.createdAt),
                                _Bubble(
                                  key: ValueKey(msg.id),
                                  message: msg,
                                  isMe: isMe,
                                  initials: _initials(widget.otherName),
                                  prevSameSender: prevSame,
                                  nextSameSender: nextSame,
                                ),
                              ],
                            );
                          },
                        );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent),
                ),
                error: (e, _) => Center(
                  child: Text('Could not load messages', style: _font(color: _textMid)),
                ),
              ),
            ),
            if (_selectedAttachment != null) _attachmentPreview(),
            _inputBar(bottom),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left, size: 20, color: _textDark),
        onPressed: () => Navigator.of(context).pop(),
        splashRadius: 20,
      ),
      title: Row(
        children: [
          // Avatar
          _Avatar(name: widget.otherName, size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.otherName, style: _font(size: 15, weight: FontWeight.w600)),
              const SizedBox(height: 1),
              Row(
                children: [
                  const Icon(Iconsax.lock1, size: 10, color: _accent),
                  const SizedBox(width: 3),
                  Text('End-to-end encrypted',
                      style: _font(size: 11, color: _accent, weight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(name: widget.otherName, size: 64),
            const SizedBox(height: 16),
            Text(widget.otherName,
                style: _font(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'This is the beginning of your encrypted\nconversation with ${widget.otherName.split(' ').first}.',
              textAlign: TextAlign.center,
              style: _font(size: 13, color: _textMid, height: 1.6),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.shield_tick, size: 13, color: _accent),
                  const SizedBox(width: 6),
                  Text('AES-256 encrypted',
                      style: _font(size: 12, color: _accent, weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSep(DateTime date) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d         = DateTime(date.year, date.month, date.day);

    final label = d == today
        ? 'Today'
        : d == yesterday
            ? 'Yesterday'
            : DateFormat('MMM d').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          label,
          style: _font(size: 11, color: _textLight, weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _attachmentPreview() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              io.File(_selectedAttachment!.path),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAttachment!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _font(size: 14, weight: FontWeight.w500),
                ),
                Text(
                  'Ready to send',
                  style: _font(size: 12, color: _accent, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.close_circle5, color: Color(0xFFEF4444)),
            onPressed: () {
              setState(() {
                _selectedAttachment = null;
              });
              _updateHasTextState();
            },
          ),
        ],
      ),
    );
  }

  Widget _inputBar(double bottomPadding) {
    return Container(
      color: _bg,
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Iconsax.image, size: 22, color: _textMid),
            onPressed: _pickAttachment,
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _chatBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border, width: 1.5),
              ),
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 5,
                style: _font(size: 14.5),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: _font(size: 14.5, color: _textLight),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _sending
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 42,
                    height: 42,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _accent),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('send'),
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _hasText ? _sentBg : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Iconsax.send1,
                        size: 18,
                        color: _hasText ? Colors.white : _textLight,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar ──────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get _color {
    const colors = [
      Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4),
      Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFFF59E0B),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final r = size * 0.3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r),
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.inter(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ),
    );
  }
}

// ─── Bubble ──────────────────────────────────────────────────────────────────
class _Bubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String initials;
  final bool prevSameSender;
  final bool nextSameSender;

  const _Bubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.initials,
    required this.prevSameSender,
    required this.nextSameSender,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  String? _text;
  bool    _busy = false;

  Future<void> _decrypt() async {
    setState(() => _busy = true);
    try {
      final d = await EncryptionService.instance.decryptMedicalRecord(
        encryptedData:   widget.message.content,
        biometricReason: 'Authenticate to read this message',
      );
      if (mounted) setState(() { _text = d; _busy = false; });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe   = widget.isMe;
    final bottom = widget.nextSameSender ? 2.0 : 8.0;

    // Bubble radius — slightly tighter corner where adjacent messages group
    final rTL = Radius.circular(isMe || widget.prevSameSender ? 18 : 4);
    final rTR = Radius.circular(!isMe || widget.prevSameSender ? 18 : 4);
    final rBL = Radius.circular(isMe ? 18 : (widget.nextSameSender ? 4 : 18));
    final rBR = Radius.circular(!isMe ? 18 : (widget.nextSameSender ? 4 : 18));

    Widget content;
    if (_text != null) {
      content = Text(_text!, style: _font(
        color: isMe ? Colors.white : _textDark,
        size: 14.5,
        height: 1.45,
      ));
    } else if (_busy) {
      content = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: isMe ? Colors.white54 : _accent,
        ),
      );
    } else {
      content = GestureDetector(
        onTap: _decrypt,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.lock1, size: 12,
                color: isMe ? Colors.white60 : _accent),
            const SizedBox(width: 5),
            Text('Tap to decrypt',
                style: _font(size: 12.5,
                    color: isMe ? Colors.white70 : _accent,
                    weight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other avatar placeholder (keeps alignment stable)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: widget.nextSameSender
                  ? const SizedBox(width: 28)
                  : _Avatar(name: _nameFromInitials(widget.initials), size: 28),
            ),
          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _sentBg : _recvBg,
                    borderRadius:
                        BorderRadius.only(topLeft: rTL, topRight: rTR, bottomLeft: rBL, bottomRight: rBR),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.message.attachmentUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            widget.message.attachmentUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 150,
                                color: const Color(0xFFF1F3F9),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 200,
                              height: 150,
                              color: const Color(0xFFFEE2E2),
                              child: const Icon(Iconsax.image, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      content,
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.jm().format(widget.message.createdAt),
                            style: _font(
                              size: 10,
                              color: isMe ? Colors.white38 : _textLight,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                              size: 12,
                              color: widget.message.isRead ? Colors.blue : Colors.white38,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // Simple reverse — avatar just needs a string to hash color from
  String _nameFromInitials(String s) => s;
}
