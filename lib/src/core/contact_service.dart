import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart' as words;
import 'package:wave_p2p/models/contact.dart';
import 'package:wave_p2p/models/friend_request.dart';

/// Сервис для управления контактами и приглашениями в Firestore
class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Создать одноразовый код приглашения (срок жизни 10 минут)
  Future<String> createFriendRequest(String myId, String myName) async {
    final code = _generateCode();
    final doc = _firestore.collection('friendRequests').doc(code);
    final req = FriendRequest(
      id: code,
      fromId: myId,
      fromName: myName,
      createdAt: DateTime.now(),
    );
    await doc.set(req.toJson());
    // Можно добавить автоматическое удаление через 10 минут (например, с помощью Cloud Functions)
    return code;
  }

  /// Проверить и активировать код приглашения
  /// Возвращает FriendRequest, если код валиден, иначе null
  Future<FriendRequest?> acceptFriendRequest(String code, String myId) async {
    final doc = _firestore.collection('friendRequests').doc(code);
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final req = FriendRequest.fromJson(code, data);
    if (req.used) return null; // уже использован
    // Проверка на истечение срока (10 минут)
    if (req.createdAt.isBefore(DateTime.now().subtract(const Duration(minutes: 10)))) {
      return null; // истёк
    }
    // Активируем код
    await doc.update({
      'used': true,
      'usedBy': myId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    return req;
  }

  /// Добавить контакт обоим пользователям (взаимное добавление)
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
      name: await _getNameForId(myId), // нужно получить имя текущего пользователя
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

  /// Подписка на список контактов пользователя
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

  /// Генерация двухсловного кода (аналогично звонкам)
  String _generateCode() {
    final p = words.generateWordPairs().take(1).first;
    return '${p.first}-${p.second}';
  }

  /// Получение имени пользователя по id (заглушка – можно хранить в отдельной коллекции)
  Future<String> _getNameForId(String id) async {
    // В реальном проекте можно хранить имена в коллекции users
    // Пока генерируем случайное имя
    return _generateRandomName();
  }

  /// Генерация случайного имени (прилагательное + существительное)
  String _generateRandomName() {
    final adj = words.generateWordPairs().take(1).first.first;
    final noun = words.generateWordPairs().take(1).first.second;
    return '${adj[0].toUpperCase()}${adj.substring(1)}${noun[0].toUpperCase()}${noun.substring(1)}';
  }
}