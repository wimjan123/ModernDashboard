import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';

class MailMessage {
  final String from;
  final String subject;
  final bool read;
  
  const MailMessage({
    required this.from,
    required this.subject,
    required this.read,
  });
  
  factory MailMessage.fromJson(Map<String, dynamic> json) => MailMessage(
    from: json['from'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    read: json['read'] as bool? ?? false,
  );
}

class MailWidget extends StatefulWidget {
  const MailWidget({super.key});

  @override
  State<MailWidget> createState() => _MailWidgetState();
}

class _MailWidgetState extends State<MailWidget> {
  List<MailMessage> _mailMessages = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMail();
  }

  Future<void> _loadMail() async {
    try {
      final mailJson = CppBridge.getMailData();
      final List<dynamic> jsonData = json.decode(mailJson) as List<dynamic>;
      
      setState(() {
        _mailMessages = jsonData
            .whereType<Map<String, dynamic>>()
            .map(MailMessage.fromJson)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _mailMessages = const [];
      });
    }
  }

  int get _unreadCount => _mailMessages.where((m) => !m.read).length;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outlined),
                const SizedBox(width: 8),
                const Text('Mail', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _mailMessages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _mailMessages.length,
                          itemBuilder: (context, i) {
                            final mail = _mailMessages[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                mail.read ? Icons.mail_outlined : Icons.markunread,
                                color: mail.read ? Colors.grey : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              title: Text(
                                mail.from,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: mail.read ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                mail.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: mail.read ? FontWeight.normal : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}