import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/contact.dart';
import '../models/contact_invite.dart';
import '../models/qr_identity.dart';
import 'user_service.dart';

class ContactService {
  ContactService._();

  static final ContactService instance = ContactService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<List<Contact>> watchContacts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .orderBy('acceptedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Contact.fromDocument).toList());
  }

  Stream<List<ContactInvite>> watchIncomingInvites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('contactInvites')
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final invites = snapshot.docs
              .map(ContactInvite.fromDocument)
              .where((invite) => invite.status == 'pending')
              .toList();
          invites.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return invites;
        });
  }

  Future<void> sendInvite(QrProfile recipient) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ContactFlowException('You are no longer signed in.');
    }
    if (recipient.ownerId == user.uid) {
      throw const ContactFlowException('You cannot add your own QR code.');
    }

    final contactReference = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .doc(recipient.ownerId);
    if ((await contactReference.get()).exists) {
      throw const ContactFlowException(
        'This person is already in your contacts.',
      );
    }

    final inviteReference = _firestore
        .collection('users')
        .doc(recipient.ownerId)
        .collection('contactInvites')
        .doc(user.uid);
    final existingInvite = await inviteReference.get();
    if (existingInvite.exists) {
      final status = existingInvite.data()?['status'];
      if (status == 'pending') {
        throw const ContactFlowException(
          'A contact invitation is already pending.',
        );
      }
      if (status == 'accepted') {
        throw const ContactFlowException(
          'This invitation was already accepted.',
        );
      }
      throw const ContactFlowException(
        'This invitation was previously declined.',
      );
    }

    final me = await UserService.instance.getCurrentUser();
    await inviteReference.set({
      'senderId': user.uid,
      'recipientId': recipient.ownerId,
      'qrToken': recipient.token,
      'status': 'pending',
      'senderProfile': {
        'displayName': me.displayName,
        'photoUrl': me.photoUrl,
        'status': me.status,
      },
      'recipientProfile': {
        'displayName': recipient.displayName,
        'photoUrl': recipient.photoUrl,
        'status': recipient.status,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptInvite(ContactInvite invite) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != invite.recipientId) {
      throw const ContactFlowException(
        'Only the recipient can accept this invitation.',
      );
    }
    final conversationId = _firestore.collection('conversations').doc().id;
    final inviteReference = _firestore
        .collection('users')
        .doc(invite.recipientId)
        .collection('contactInvites')
        .doc(invite.senderId);
    final recipientContact = _firestore
        .collection('users')
        .doc(invite.recipientId)
        .collection('contacts')
        .doc(invite.senderId);
    final senderContact = _firestore
        .collection('users')
        .doc(invite.senderId)
        .collection('contacts')
        .doc(invite.recipientId);
    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final memberIds = [invite.recipientId, invite.senderId]..sort();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(inviteReference, {
      'status': 'accepted',
      'conversationId': conversationId,
      'respondedAt': now,
      'updatedAt': now,
    });
    batch.set(recipientContact, {
      'peerId': invite.senderId,
      'conversationId': conversationId,
      'peerProfile': {
        'displayName': invite.senderName,
        'photoUrl': invite.senderPhotoUrl,
        'status': invite.senderStatus,
      },
      'acceptedAt': now,
    });
    batch.set(senderContact, {
      'peerId': invite.recipientId,
      'conversationId': conversationId,
      'peerProfile': {
        'displayName': invite.recipientName,
        'photoUrl': invite.recipientPhotoUrl,
        'status': invite.recipientStatus,
      },
      'acceptedAt': now,
    });
    batch.set(conversation, {
      'type': 'direct',
      'memberIds': memberIds,
      'memberProfiles': {
        invite.senderId: {
          'displayName': invite.senderName,
          'photoUrl': invite.senderPhotoUrl,
        },
        invite.recipientId: {
          'displayName': invite.recipientName,
          'photoUrl': invite.recipientPhotoUrl,
        },
      },
      'updatedAt': now,
    });
    await batch.commit();
  }

  Future<void> declineInvite(ContactInvite invite) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != invite.recipientId) {
      throw const ContactFlowException(
        'Only the recipient can decline this invitation.',
      );
    }
    await _firestore
        .collection('users')
        .doc(invite.recipientId)
        .collection('contactInvites')
        .doc(invite.senderId)
        .update({
          'status': 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

class ContactFlowException implements Exception {
  const ContactFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}
