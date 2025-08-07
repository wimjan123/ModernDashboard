import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../firebase/firebase_service.dart';

class MailWidget extends StatefulWidget {
  const MailWidget({super.key});

  @override
  State<MailWidget> createState() => _MailWidgetState();
}

// Enhanced mock mail message for demonstration
class MockMailMessage {
  final String id;
  final String from;
  final String subject;
  final String preview;
  final bool read;
  final DateTime receivedAt;
  final String category;
  
  const MockMailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.preview,
    required this.read,
    required this.receivedAt,
    this.category = 'inbox',
  });
  
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(receivedAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _MailWidgetState extends State<MailWidget> {
  List<MockMailMessage> _mailMessages = [];
  final TextEditingController _accountController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _currentAccount = 'demo@example.com';

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMockMail();
  }

  Future<void> _loadMockMail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Generate mock mail data stored per user in Firebase
      final userId = FirebaseService.instance.getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Simulate personalized mock mail data
      final mockMails = _generateMockMails(userId);
      
      setState(() {
        _mailMessages = mockMails;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load mail: $e';
        _mailMessages = [];
      });
    }
  }

  List<MockMailMessage> _generateMockMails(String userId) {
    // Generate consistent mock data based on user ID
    final baseTime = DateTime.now();
    final userSeed = userId.hashCode.abs();
    
    return [
      MockMailMessage(
        id: '1',
        from: 'Flutter Team',
        subject: 'Welcome to Modern Dashboard!',
        preview: 'Thank you for using our Firebase-powered dashboard application...',
        read: userSeed % 3 == 0,
        receivedAt: baseTime.subtract(const Duration(hours: 2)),
      ),
      MockMailMessage(
        id: '2',
        from: 'Firebase Updates',
        subject: 'New Firebase Features Available',
        preview: 'Discover the latest Firebase features including improved Firestore offline support...',
        read: userSeed % 2 == 0,
        receivedAt: baseTime.subtract(const Duration(hours: 6)),
      ),
      MockMailMessage(
        id: '3',
        from: 'System Notification',
        subject: 'Your data has been successfully migrated',
        preview: 'All your todos, weather preferences, and news feeds are now synced...',
        read: true,
        receivedAt: baseTime.subtract(const Duration(days: 1)),
      ),
      MockMailMessage(
        id: '4',
        from: 'Development Team',
        subject: 'Feature Request: Real Email Integration',
        preview: 'We are working on integrating real email services like Gmail and Outlook...',
        read: userSeed % 4 != 0,
        receivedAt: baseTime.subtract(const Duration(days: 2)),
      ),
      MockMailMessage(
        id: '5',
        from: 'Security Alert',
        subject: 'New device logged into your account',
        preview: 'A new device has been used to access your Modern Dashboard account...',
        read: false,
        receivedAt: baseTime.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  Future<void> _toggleReadStatus(MockMailMessage message) async {
    // Simulate toggling read status with Firebase storage
    setState(() {
      final index = _mailMessages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _mailMessages[index] = MockMailMessage(
          id: message.id,
          from: message.from,
          subject: message.subject,
          preview: message.preview,
          read: !message.read,
          receivedAt: message.receivedAt,
          category: message.category,
        );
      }
    });

    // In a real implementation, this would update Firebase
    // final userDoc = FirebaseService.instance.getUserDocument();
    // await userDoc.collection('mail').doc(message.id).update({'read': !message.read});
  }

  Future<void> _configureAccount() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) return;

    setState(() {
      _currentAccount = account;
      _error = null;
    });
    
    _accountController.clear();
    
    // Show configuration success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mock account "$account" configured'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
    
    // Reload mock mail for the new account
    await _loadMockMail();
  }

  int get _unreadCount => _mailMessages.where((m) => !m.read).length;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Messages',
      icon: Stack(
        children: [
          const Icon(
            Icons.mail_rounded,
            color: Color(0xFF8B5CF6),
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
      child: Consumer<FirebaseService>(
        builder: (context, firebaseService, child) {
          if (!firebaseService.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8B5CF6),
              ),
            );
          }

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8B5CF6),
              ),
            );
          }

          if (_error != null && _mailMessages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: DarkThemeData.errorColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DarkThemeData.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMockMail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (_mailMessages.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 32,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No messages for $_currentAccount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _accountController,
                        decoration: InputDecoration(
                          hintText: 'Enter email account...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _configureAccount(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _configureAccount,
                      icon: const Icon(Icons.settings_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              // Account info and actions at top
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_rounded,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentAccount,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_unreadCount unread',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadMockMail,
                      icon: const Icon(Icons.refresh_rounded),
                      iconSize: 18,
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ],
                ),
              ),

              // Mail list
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _mailMessages.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF334155),
                  ),
                  itemBuilder: (context, i) {
                    final mail = _mailMessages[i];
                    return InkWell(
                      onTap: () => _toggleReadStatus(mail),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: mail.read
                                    ? Colors.transparent
                                    : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: mail.read
                                      ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                                      : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                mail.read ? Icons.mail_outlined : Icons.markunread_rounded,
                                color: mail.read
                                    ? Theme.of(context).colorScheme.outline
                                    : const Color(0xFF8B5CF6),
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          mail.from,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: mail.read ? FontWeight.w400 : FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        mail.getTimeAgo(),
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mail.subject,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: mail.read ? 0.6 : 0.8),
                                      fontWeight: mail.read ? FontWeight.w400 : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mail.preview,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}