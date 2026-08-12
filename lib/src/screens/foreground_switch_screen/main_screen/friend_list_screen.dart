import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:md_ui_kit/md_ui_kit.dart';
import 'package:wave_p2p/src/core/webrtc_manager.dart';
import 'package:wave_p2p/models/contact.dart';

/// Экран списка друзей
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
      mainAxisSize: MainAxisSize.min, // Важно: не растягиваться на всю высоту
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const WaveText('Друзья', type: WaveTextType.title),
              WaveSimpleButton(
                label: 'Добавить',
                onPressed: () => _showAddFriendDialog(context),
                type: WaveButtonType.main,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ],
          ),
        ),
        // Если контактов нет – показываем сообщение, иначе список
        contacts.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Нет друзей. Добавьте первого!')),
              )
            : ListView.builder(
                shrinkWrap: true, // Важно: занимает только необходимую высоту
                physics:
                    const NeverScrollableScrollPhysics(), // Отключаем внутренний скролл
                itemCount: contacts.length,
                itemBuilder: (_, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(contact.displayName[0])),
                    title: Text(contact.displayName),
                    subtitle: Text(contact.id),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_note),
                      onPressed: () => _editNote(context, contact),
                    ),
                    onTap: () => _openChatWithContact(context, contact),
                    onLongPress: () => _callContact(context, contact),
                  );
                },
              ),
      ],
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddFriendDialog(),
    );
  }

  void _editNote(BuildContext context, Contact contact) {
    final controller = TextEditingController(text: contact.note ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Заметка для ${contact.displayName}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Введите заметку'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final note = controller.text.trim();
              final manager = context.read<WebRTCManager>();
              await manager.updateContactNote(contact.id, note);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _openChatWithContact(BuildContext context, Contact contact) {
    // TODO: открыть чат с контактом (можно использовать существующий ChatScreen, передав contactId)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Чат с ${contact.displayName} (в разработке)')),
    );
  }

  void _callContact(BuildContext context, Contact contact) {
    // TODO: инициировать звонок контакту (создать offer и сохранить в Firestore)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Звонок ${contact.displayName} (в разработке)')),
    );
  }
}

/// Диалог добавления друга (создание или ввод кода)
class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key});

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить друга'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Введите код приглашения:'),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(hintText: 'например: red-fox'),
          ),
          const SizedBox(height: 16),
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
          if (_isLoading) const CircularProgressIndicator(),
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
          title: const Text('Ваш код приглашения'),
          content: Text(code),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
      if (context.mounted) {
        Navigator.pop(context); // закрыть диалог
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Друг добавлен!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
