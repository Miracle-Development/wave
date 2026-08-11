import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart' as words;
import 'package:wave_p2p/models/contact.dart';
import 'package:wave_p2p/models/friend_request.dart';

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Создать одноразовый код для добавления друга
  Future<String> createFriendRequest(String myId, String myName) async {
    final code = _generateCode(); // используем генерацию из WebRTCManager
    final doc = _firestore.collection('friendRequests').doc(code);
    final req = FriendRequest(
      id: code,
      fromId: myId,
      fromName: myName,
      createdAt: DateTime.now(),
    );
    await doc.set(req.toJson());
    // Установим автоматическое удаление через 10 минут (Firestore TTL)
    // Можно использовать scheduled function, но проще установить expiresAt и проверять.
    return code;
  }

  /// Проверить и активировать код
  Future<FriendRequest?> acceptFriendRequest(String code, String myId) async {
    final doc = _firestore.collection('friendRequests').doc(code);
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final req = FriendRequest.fromJson(code, data);
    if (req.used) return null; // уже использован
    // Проверяем, не истёк ли (старше 10 минут)
    if (req.createdAt.isBefore(DateTime.now().subtract(Duration(minutes: 10)))) {
      return null; // истёк
    }
    // Активируем
    await doc.update({
      'used': true,
      'usedBy': myId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    return req;
  }

  /// Добавить контакт обоим пользователям
  Future<void> addContact(String myId, String friendId, String friendName) async {
    final myRef = _firestore.collection('contacts').doc(myId);
    final friendRef = _firestore.collection('contacts').doc(friendId);

    final myContact = Contact(
      id: friendId,
      name: friendName,
      addedAt: DateTime.now(),
    );
    final friendContact = Contact(
      id: myId,
      name: await _getNameForId(myId),
      addedAt: DateTime.now(),
    );

    await _firestore.runTransaction((txn) async {
      txn.update(myRef, {
        'list': FieldValue.arrayUnion([myContact.toJson()]),
      });
      txn.update(friendRef, {
        'list': FieldValue.arrayUnion([friendContact.toJson()]),
      });
    });
  }

  /// Получить все контакты пользователя
  Stream<List<Contact>> watchContacts(String myId) {
    return _firestore
        .collection('contacts')
        .doc(myId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <Contact>[];
      final list = snap.data()?['list'] as List? ?? [];
      return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  /// Обновить заметку контакта
  Future<void> updateContactNote(String myId, String contactId, String note) async {
    final doc = _firestore.collection('contacts').doc(myId);
    final snap = await doc.get();
    if (!snap.exists) return;
    final list = List<Map<String, dynamic>>.from(snap.data()?['list'] ?? []);
    final index = list.indexWhere((e) => e['contactId'] == contactId);
    if (index == -1) return;
    list[index]['note'] = note;
    await doc.update({'list': list});
  }

  String _generateCode() {
    // Используем двухсловный код, как в calls
    final p = words.generateWordPairs().take(1).first;
    return '${p.first}-${p.second}';
  }

  Future<String> _getNameForId(String id) async {
    // Можно хранить в отдельной коллекции пользователей, но пока генерируем
    return 'User_$id'; // или использовать слова
  }
}