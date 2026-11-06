import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'user_service.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<Conversation?> watchConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? Conversation.fromDocument(snapshot) : null,
        );
  }

  Stream<List<String>> watchGroupConversationIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('groupConversations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => document.data()['conversationId'])
              .whereType<String>()
              .toList(),
        );
  }

  Future<ChatRouteArguments> createGroup({
    required String name,
    required List<Contact> contacts,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('You are no longer signed in.');
    final cleanName = name.trim();
    if (cleanName.length < 2 || cleanName.length > 60) {
      throw ArgumentError('Group name must be 2–60 characters.');
    }
    final uniqueContacts = <String, Contact>{
      for (final contact in contacts) contact.peerId: contact,
    };
    if (uniqueContacts.length < 2 || uniqueContacts.length > 4) {
      throw ArgumentError('Choose 2–4 contacts for a group.');
    }
    if (uniqueContacts.containsKey(userId)) {
      throw ArgumentError('You cannot add yourself as a contact.');
    }

    final me = await UserService.instance.getCurrentUser();
    final peerIds = uniqueContacts.keys.toList()..sort();
    final memberIds = [userId, ...peerIds];
    final memberProfiles = <String, dynamic>{
      userId: me.conversationProfile,
      for (final peerId in peerIds)
        peerId: {
          'displayName': uniqueContacts[peerId]!.displayName,
          'photoUrl': uniqueContacts[peerId]!.photoUrl,
        },
    };
    final unreadCounts = <String, int>{
      for (final memberId in memberIds) memberId: 0,
    };
    final conversation = _firestore.collection('conversations').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(conversation, {
      'type': 'group',
      'name': cleanName,
      'creatorId': userId,
      'memberIds': memberIds,
      'memberProfiles': memberProfiles,
      'unreadCounts': unreadCounts,
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastSenderId': '',
      'createdAt': now,
      'updatedAt': now,
    });
    for (final memberId in memberIds) {
      batch.set(
        _firestore
            .collection('users')
            .doc(memberId)
            .collection('groupConversations')
            .doc(conversation.id),
        {
          'conversationId': conversation.id,
          'creatorId': userId,
          'createdAt': now,
        },
      );
    }
    await batch.commit();
    return ChatRouteArguments(
      conversationId: conversation.id,
      peer: ConversationPeer(id: '', displayName: cleanName, photoUrl: ''),
    );
  }

  Stream<List<Conversation>> watchConversations(String userId) {
    final authenticatedUserId = _auth.currentUser?.uid;
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      return Stream.error(StateError('You are no longer signed in.'));
    }
    return _firestore
        .collection('conversations')
        .where('memberIds', arrayContains: authenticatedUserId)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(Conversation.fromDocument)
              .toList();
          conversations.sort((a, b) {
            final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return conversations;
        });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ChatMessage.fromDocument).toList(),
        );
  }

  Future<ChatRouteArguments> createOrOpenDirectConversation(
    Contact contact,
  ) async {
    final me = await UserService.instance.getCurrentUser();
    final ids = [me.id, contact.peerId]..sort();
    final reference = _firestore
        .collection('conversations')
        .doc(contact.conversationId);
    await reference.set({
      'type': 'direct',
      'memberIds': ids,
      'memberProfiles': {
        me.id: me.conversationProfile,
        contact.peerId: {
          'displayName': contact.displayName,
          'photoUrl': contact.photoUrl,
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ChatRouteArguments(
      conversationId: contact.conversationId,
      peer: ConversationPeer(
        id: contact.peerId,
        displayName: contact.displayName,
        photoUrl: contact.photoUrl,
      ),
    );
  }

  Future<void> sendText({
    required String conversationId,
    required String text,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('You are no longer signed in.');
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final conversationSnapshot = await conversation.get();
    if (!conversationSnapshot.exists) {
      throw StateError('Conversation does not exist.');
    }
    final memberIds = List<String>.from(
      conversationSnapshot.data()?['memberIds'] as List? ?? const [],
    );
    final unreadUpdates = <String, dynamic>{};
    for (final memberId in memberIds) {
      unreadUpdates['unreadCounts.$memberId'] = memberId == userId
          ? 0
          : FieldValue.increment(1);
    }

    final message = conversation.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(message, {
      'senderId': userId,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'lastMessage': cleanText,
      'lastMessageType': 'text',
      'lastSenderId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });
    await batch.commit();
  }

  Future<void> markRead(String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('You are no longer signed in.');
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$userId': 0,
    });
  }
}
