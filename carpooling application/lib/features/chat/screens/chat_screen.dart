import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherUserName;
  final bool isDriver;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherUserName,
    required this.isDriver,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final me = await ApiService.get('/users/me');
      _myId = me['user']['id'].toString();
      final data = await ApiService.get('/messages/${widget.bookingId}');
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _loading = false;
      });
      _scrollToBottom();
      SocketService.instance.onMessage(widget.bookingId, (msg) {
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await ApiService.post('/messages/${widget.bookingId}', {'content': text});
    } catch (_) {}
    finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isMe(Map<String, dynamic> msg) => msg['sender_id'].toString() == _myId;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(widget.isDriver ? 'Passenger' : 'Driver', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppTheme.textTertiary),
                            const SizedBox(height: 12),
                            const Text('No messages yet', style: TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            const Text('Say hi to start the conversation!', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMe = _isMe(msg);
                          final showTime = i == 0 || _shouldShowTime(_messages[i - 1], msg);
                          return Column(
                            children: [
                              if (showTime) _TimeDivider(timestamp: msg['created_at']),
                              _MessageBubble(msg: msg, isMe: isMe),
                            ],
                          );
                        },
                      ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        filled: true,
                        fillColor: AppTheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowTime(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    try {
      final prevTime = DateTime.parse(prev['created_at']);
      final currTime = DateTime.parse(curr['created_at']);
      return currTime.difference(prevTime).inMinutes > 10;
    } catch (_) { return false; }
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              child: Text(
                (msg['sender_name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: AppTheme.cardShadow,
                border: isMe ? null : Border.all(color: AppTheme.border),
              ),
              child: Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TimeDivider extends StatelessWidget {
  final String? timestamp;
  const _TimeDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    String label = '';
    try {
      final dt = DateTime.parse(timestamp!).toLocal();
      label = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
