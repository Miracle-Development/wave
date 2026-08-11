import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/models/contact.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WebRTCManager>();
    final contacts = manager.contacts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WaveText('Друзья', type: WaveTextType.title),
              WaveSimpleButton(
                label: 'Добавить',
                onPressed: () => _showAddFriendDialog(context),
                type: WaveButtonType.main,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (_, index) {
              final contact = contacts[index];
              return ListTile(
                title: Text(contact.displayName),
                subtitle: Text(contact.id),
                trailing: IconButton(
                  icon: Icon(Icons.edit_note),
                  onPressed: () => _editNote(context, contact),
                ),
                onTap: () => _openChatWithContact(context, contact),
                onLongPress: () => _callContact(context, contact),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddFriendDialog(),
    );
  }

  void _editNote(BuildContext context, Contact contact) {
    // Показываем диалог с полем ввода
    // ...
  }

  void _openChatWithContact(BuildContext context, Contact contact) {
    // Переход в чат (используем существующий чат)
    // Можно создать отдельный экран чата или переиспользовать ChatScreen, указав контакт
  }

  void _callContact(BuildContext context, Contact contact) {
    // Инициировать звонок (создать offer и отправить через Firestore)
    // Пока можно просто вывести сообщение
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Звонок контакту ${contact.displayName}')),
    );
  }
}

class AddFriendDialog extends StatefulWidget {
  @override
  _AddFriendDialogState createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Добавить друга'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Введите код приглашения:'),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(hintText: 'например: red-fox'),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              WaveSimpleButton(
                label: 'Создать код',
                onPressed: _isLoading ? null : _createCode,
                type: WaveButtonType.alternative,
              ),
              WaveSimpleButton(
                label: 'Принять',
                onPressed: _isLoading ? null : _acceptCode,
                type: WaveButtonType.main,
              ),
            ],
          ),
          if (_isLoading) CircularProgressIndicator(),
        ],
      ),
    );
  }

  Future<void> _createCode() async {
    setState(() => _isLoading = true);
    try {
      final manager = context.read<WebRTCManager>();
      final code = await manager.createInviteCode();
      // Показать код пользователю
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Ваш код приглашения'),
          content: Text(code),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final manager = context.read<WebRTCManager>();
      await manager.acceptInviteCode(code);
      Navigator.pop(context); // закрыть диалог
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Друг добавлен!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}