import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';

// Conditional import for FFI (web uses stub)
import '../../services/ffi_bridge.dart' if (dart.library.html) '../../services/ffi_bridge_web.dart';

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
      String mailJson;
      if (kIsWeb) {
        mailJson = FfiBridge.getMailData();
      } else {
        mailJson = FfiBridge.isSupported ? FfiBridge.getMailData() : CppBridge.getMailData();
      }
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
    return GlassInfoCard(
      title: 'Messages',
      icon: Stack(
        children: [
          Icon(
            Icons.mail_rounded,
            color: const Color(0xFF8B5CF6),
            size: 20,
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DarkThemeData.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      accentColor: const Color(0xFF8B5CF6),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8B5CF6),
              ),
            )
          : _mailMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 32,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No messages',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _mailMessages.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF334155),
                  ),
                  itemBuilder: (context, i) {
                    final mail = _mailMessages[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: mail.read
                                  ? Colors.transparent
                                  : const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: mail.read
                                    ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                                    : const Color(0xFF8B5CF6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              mail.read ? Icons.mail_outlined : Icons.markunread_rounded,
                              color: mail.read
                                  ? Theme.of(context).colorScheme.outline
                                  : const Color(0xFF8B5CF6),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mail.from,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: mail.read ? FontWeight.w400 : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mail.subject,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}