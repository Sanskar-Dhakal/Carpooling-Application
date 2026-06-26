import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String currentUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  IO.Socket? _socket;
  final List<Map<String, dynamic>> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _driverOffline = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectSocket();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiService.get('/messages/${widget.bookingId}');
      final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      setState(() { _messages.addAll(msgs); _loading = false; });
      _markRead();
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ApiService.put('/messages/${widget.bookingId}/read-all', {});
    } catch (_) {}
  }

  Future<void> _connectSocket() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    _socket = IO.io(
      AppConstants.baseUrl.replaceAll('/api/v1', ''),
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onConnect((_) {
      _socket!.emit('join_chat', widget.bookingId);
      setState(() => _driverOffline = false);
    });
    _socket!.on('new_message', (data) {
      setState(() => _messages.add(Map<String, dynamic>.from(data)));
      _scrollToBottom();
      _markRead();
    });
    _socket!.on('read_receipt', (data) {
      final msgId = data['messageId'];
      setState(() {
        for (final m in _messages) {
          if (m['id'] == msgId) m['is_read'] = true;
        }
      });
    });
    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _driverOffline = true);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _socket?.emit('send_message', {'bookingId': widget.bookingId, 'content': text});
    _controller.clear();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isMine(Map<String, dynamic> msg) =>
      msg['sender_id'] == widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: AppTheme.primary,
        actions: [
          if (_driverOffline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.signal_wifi_off, color: Colors.redAccent),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_driverOffline)
            Container(
              width: double.infinity,
              color: AppTheme.error.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Text('The other user is offline',
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                  textAlign: TextAlign.center),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet.\nSay hello!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _buildBubble(_messages[i]),
                      ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final mine = _isMine(msg);
    final isRead = msg['is_read'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine && msg['sender_name'] != null)
              Text(msg['sender_name'],
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
            Text(msg['content'] ?? '',
                style: TextStyle(color: mine ? Colors.white : AppTheme.textPrimary, fontSize: 14)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg['created_at']),
                  style: TextStyle(
                      fontSize: 10,
                      color: mine ? Colors.white60 : AppTheme.textSecondary),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: isRead ? Colors.lightBlueAccent : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
