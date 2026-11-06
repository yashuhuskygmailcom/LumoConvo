import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../routes.dart';
import '../services/chat_service.dart';
import '../services/contact_service.dart';
import '../theme/haychat_theme.dart';
import '../widgets/authorized_profile_builder.dart';
import '../widgets/hay_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.currentUserId, super.key});

  final String currentUserId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  String _query = '';

  void _onDestination(int value) {
    if (value == 2) {
      Navigator.pushNamed(context, HayRoutes.profile);
      return;
    }
    setState(() {
      _index = value;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _index == 0 ? 'Chats' : 'Contacts';
    return HayScaffold(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              backgroundColor: HayColors.gold,
              foregroundColor: const Color(0xFF23180B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, HayRoutes.newConversation),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          if (_index == 1) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, HayRoutes.scanQr),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, HayRoutes.contactInvites),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Invites'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          HaySearchField(
            hint: 'Search ${_index == 0 ? 'conversations' : 'contacts'}',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _index == 0
                ? _ConversationList(
                    query: _query,
                    currentUserId: widget.currentUserId,
                  )
                : _ContactList(
                    query: _query,
                    currentUserId: widget.currentUserId,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.query, required this.currentUserId});

  final String query;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: ContactService.instance.watchContacts(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamError(message: _friendlyDataError(snapshot.error!));
        }
        final available = snapshot.data;
        if (available == null) return const _LoadingList();
        final contacts = available
            .where(
              (contact) => contact.displayName.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
        return StreamBuilder<List<String>>(
          stream: ChatService.instance.watchGroupConversationIds(currentUserId),
          builder: (context, groupSnapshot) {
            final groupIds = groupSnapshot.data ?? const <String>[];
            if (contacts.isEmpty && groupIds.isEmpty) {
              return const _EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No conversations yet',
                message: 'Add a contact, then tap + to start chatting.',
              );
            }
            return ListView.separated(
              itemCount: groupIds.length + contacts.length,
              separatorBuilder: (_, _) => const Hairline(),
              itemBuilder: (context, index) {
                if (index < groupIds.length) {
                  return _GroupConversationTile(
                    conversationId: groupIds[index],
                    currentUserId: currentUserId,
                    query: query,
                  );
                }
                return _ContactConversationTile(
                  contact: contacts[index - groupIds.length],
                  currentUserId: currentUserId,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GroupConversationTile extends StatelessWidget {
  const _GroupConversationTile({
    required this.conversationId,
    required this.currentUserId,
    required this.query,
  });

  final String conversationId;
  final String currentUserId;
  final String query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Conversation?>(
      stream: ChatService.instance.watchConversation(conversationId),
      builder: (context, snapshot) {
        final conversation = snapshot.data;
        if (conversation == null) {
          return const SizedBox.shrink();
        }
        final peer = conversation.presentationFor(currentUserId);
        if (!peer.displayName.toLowerCase().contains(query.toLowerCase())) {
          return const SizedBox.shrink();
        }
        return _ConversationTile(
          peer: peer,
          message: conversation.lastMessage.isEmpty
              ? '${conversation.memberIds.length} members'
              : conversation.lastMessage,
          time: _formatConversationTime(conversation.updatedAt),
          unread: conversation.unreadFor(currentUserId),
          onTap: () => Navigator.pushNamed(
            context,
            HayRoutes.conversation,
            arguments: ChatRouteArguments(
              conversationId: conversation.id,
              peer: peer,
            ),
          ),
        );
      },
    );
  }
}

class _ContactConversationTile extends StatelessWidget {
  const _ContactConversationTile({
    required this.contact,
    required this.currentUserId,
  });

  final Contact contact;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return AuthorizedProfileBuilder(
      key: ValueKey(contact.peerId),
      userId: contact.peerId,
      builder: (context, profile) {
        final peer = ConversationPeer(
          id: contact.peerId,
          displayName: profile?.displayName ?? contact.displayName,
          photoUrl: profile?.photoUrl ?? contact.photoUrl,
          avatarBytes: profile?.avatarBytes,
        );
        return StreamBuilder<Conversation?>(
          stream: ChatService.instance.watchConversation(
            contact.conversationId,
          ),
          builder: (context, snapshot) {
            final conversation = snapshot.data;
            final unavailable = snapshot.hasError;
            return _ConversationTile(
              peer: peer,
              message: unavailable
                  ? 'Tap to sync this conversation'
                  : conversation == null || conversation.lastMessage.isEmpty
                  ? 'Start the conversation'
                  : conversation.lastMessage,
              time: _formatConversationTime(conversation?.updatedAt),
              unread: conversation?.unreadFor(currentUserId) ?? 0,
              onTap: () => _openContact(context, contact),
            );
          },
        );
      },
    );
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList({required this.query, required this.currentUserId});

  final String query;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: ContactService.instance.watchContacts(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamError(message: _friendlyDataError(snapshot.error!));
        }
        final available = snapshot.data;
        if (available == null) return const _LoadingList();
        final contacts = available
            .where(
              (contact) => contact.displayName.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
        if (contacts.isEmpty) {
          return const _EmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: 'No contacts yet',
            message: 'Scan a QR code and wait for the invite to be accepted.',
          );
        }
        return ListView.separated(
          itemCount: contacts.length,
          separatorBuilder: (_, _) => const Hairline(),
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return AuthorizedProfileBuilder(
              key: ValueKey(contact.peerId),
              userId: contact.peerId,
              builder: (context, profile) {
                final displayName = profile?.displayName ?? contact.displayName;
                final status = profile?.status ?? contact.status;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  onTap: () => _openContact(context, contact),
                  leading: HayAvatar(
                    initials: profile?.initials ?? contact.initials,
                    imageBytes: profile?.avatarBytes,
                    photoUrl: profile?.photoUrl ?? contact.photoUrl,
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: HayColors.muted,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

Future<void> _openContact(BuildContext context, Contact contact) async {
  try {
    final arguments = await ChatService.instance.createOrOpenDirectConversation(
      contact,
    );
    if (context.mounted) {
      await Navigator.pushNamed(
        context,
        HayRoutes.conversation,
        arguments: arguments,
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyDataError(error))));
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.peer,
    required this.message,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final ConversationPeer peer;
  final String message;
  final String time;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      minTileHeight: 64,
      onTap: onTap,
      leading: HayAvatar(
        initials: peer.initials,
        imageBytes: peer.avatarBytes,
        photoUrl: peer.photoUrl,
      ),
      title: Text(
        peer.displayName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(fontSize: 9, color: HayColors.muted),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: HayColors.gold,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Color(0xFF23180B),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({required this.userId, super.key});

  final String userId;

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  String _query = '';
  Contact? _selected;
  bool _loading = false;

  Future<void> _startChat() async {
    final contact = _selected;
    if (contact == null || _loading) return;
    setState(() => _loading = true);
    try {
      final arguments = await ChatService.instance
          .createOrOpenDirectConversation(contact);
      if (mounted) {
        await Navigator.pushReplacementNamed(
          context,
          HayRoutes.conversation,
          arguments: arguments,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyDataError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HayBackButton(),
          Text(
            'New Conversation',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, HayRoutes.createGroup),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Create Group'),
            ),
          ),
          const SizedBox(height: 14),
          HaySearchField(
            hint: 'Search contacts',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Contact>>(
              stream: ContactService.instance.watchContacts(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _StreamError(
                    message: _friendlyDataError(snapshot.error!),
                  );
                }
                final available = snapshot.data;
                if (available == null) return const _LoadingList();
                final contacts = available
                    .where(
                      (contact) => contact.displayName.toLowerCase().contains(
                        _query.toLowerCase(),
                      ),
                    )
                    .toList();
                if (contacts.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No accepted contacts',
                    message:
                        'Scan a QR code and have the invite accepted first.',
                  );
                }
                return RadioGroup<String>(
                  groupValue: _selected?.peerId,
                  onChanged: (id) {
                    setState(
                      () => _selected = contacts.firstWhere(
                        (contact) => contact.peerId == id,
                      ),
                    );
                  },
                  child: ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const Hairline(),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        onTap: () => setState(() => _selected = contact),
                        leading: HayAvatar(
                          initials: contact.initials,
                          photoUrl: contact.photoUrl,
                        ),
                        title: Text(
                          contact.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Radio<String>(
                          value: contact.peerId,
                          activeColor: HayColors.gold,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          HayPrimaryButton(
            label: _loading ? 'Starting...' : 'Start Chat',
            onPressed: _selected != null && !_loading ? _startChat : null,
          ),
        ],
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({required this.userId, super.key});

  final String userId;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String _query = '';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(List<Contact> contacts) async {
    if (_loading) return;
    final selected = contacts
        .where((contact) => _selectedIds.contains(contact.peerId))
        .toList();
    setState(() => _loading = true);
    try {
      final arguments = await ChatService.instance.createGroup(
        name: _nameController.text,
        contacts: selected,
      );
      if (mounted) {
        await Navigator.pushReplacementNamed(
          context,
          HayRoutes.conversation,
          arguments: arguments,
        );
      }
    } catch (error) {
      if (mounted) _showDataError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HayBackButton(),
          Text(
            'Create Group',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose 2–4 accepted contacts. You are included automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Group name',
              prefixIcon: Icon(Icons.group_outlined),
            ),
          ),
          const SizedBox(height: 10),
          HaySearchField(
            hint: 'Search accepted contacts',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedIds.length}/4 selected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<List<Contact>>(
              stream: ContactService.instance.watchContacts(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _StreamError(
                    message: _friendlyDataError(snapshot.error!),
                  );
                }
                final allContacts = snapshot.data;
                if (allContacts == null) return const _LoadingList();
                final contacts = allContacts
                    .where(
                      (contact) => contact.displayName.toLowerCase().contains(
                        _query.toLowerCase(),
                      ),
                    )
                    .toList();
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, _) => const Hairline(),
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final selected = _selectedIds.contains(
                            contact.peerId,
                          );
                          final disabled =
                              !selected && _selectedIds.length >= 4;
                          return ListTile(
                            enabled: !disabled,
                            onTap: disabled
                                ? null
                                : () => setState(() {
                                    if (selected) {
                                      _selectedIds.remove(contact.peerId);
                                    } else {
                                      _selectedIds.add(contact.peerId);
                                    }
                                  }),
                            leading: HayAvatar(
                              initials: contact.initials,
                              photoUrl: contact.photoUrl,
                            ),
                            title: Text(contact.displayName),
                            trailing: Checkbox(
                              value: selected,
                              activeColor: HayColors.gold,
                              onChanged: disabled
                                  ? null
                                  : (_) => setState(() {
                                      if (selected) {
                                        _selectedIds.remove(contact.peerId);
                                      } else {
                                        _selectedIds.add(contact.peerId);
                                      }
                                    }),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    HayPrimaryButton(
                      label: _loading ? 'Creating...' : 'Create Group',
                      onPressed:
                          !_loading &&
                              _selectedIds.length >= 2 &&
                              _nameController.text.trim().length >= 2
                          ? () => _createGroup(allContacts)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.arguments,
    required this.currentUserId,
    super.key,
  });

  final ChatRouteArguments arguments;
  final String currentUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      ChatService.instance
          .markRead(widget.arguments.conversationId)
          .catchError((_) {}),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendText(
        conversationId: widget.arguments.conversationId,
        text: text,
      );
    } catch (error) {
      _controller.text = text;
      if (mounted) _showDataError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          _ChatHeader(peer: widget.arguments.peer),
          const Hairline(),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.instance.watchMessages(
                widget.arguments.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _StreamError(
                    message: _friendlyDataError(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) return const _LoadingList();
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Say hello',
                    message: 'Messages are private to this conversation.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: messages[index],
                    sent: messages[index].senderId == widget.currentUserId,
                  ),
                );
              },
            ),
          ),
          _Composer(controller: _controller, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.peer});

  final ConversationPeer peer;

  @override
  Widget build(BuildContext context) {
    if (peer.id.isEmpty) {
      return _buildHeader(context, peer, '${peer.displayName} group');
    }
    return AuthorizedProfileBuilder(
      userId: peer.id,
      builder: (context, profile) {
        final currentPeer = ConversationPeer(
          id: peer.id,
          displayName: profile?.displayName ?? peer.displayName,
          photoUrl: profile?.photoUrl ?? peer.photoUrl,
          avatarBytes: profile?.avatarBytes,
        );
        return _buildHeader(context, currentPeer, 'HayChat');
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ConversationPeer currentPeer,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 17,
              color: HayColors.ivoryDim,
            ),
          ),
          HayAvatar(
            initials: currentPeer.initials,
            size: 37,
            imageBytes: currentPeer.avatarBytes,
            photoUrl: currentPeer.photoUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPeer.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'HayChat',
                  style: TextStyle(fontSize: 10, color: HayColors.sage),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.call_outlined,
              size: 19,
              color: HayColors.ivoryDim,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: HayColors.ivoryDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.sent});

  final ChatMessage message;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .74,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 6),
        decoration: _bubbleDecoration(sent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: sent ? HayColors.ivory : HayColors.ivoryDim,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatMessageTime(message.createdAt),
              style: const TextStyle(fontSize: 8, color: HayColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
    decoration: BoxDecoration(
      color: HayColors.input,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: HayColors.hairlineSoft),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onSend(),
            cursorColor: HayColors.gold,
            style: const TextStyle(fontSize: 13, color: HayColors.ivory),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Type a message...',
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [HayColors.goldSoft, HayColors.gold],
            ),
          ),
          child: IconButton(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF23180B),
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: Color(0xFF23180B),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: HayColors.gold, strokeWidth: 2),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: HayColors.sageDim),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _StreamError extends StatelessWidget {
  const _StreamError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: HayColors.clay, fontSize: 12),
      ),
    ),
  );
}

BoxDecoration _bubbleDecoration(bool sent) => BoxDecoration(
  color: sent ? null : const Color(0xFF24342B),
  gradient: sent
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E6350), Color(0xFF2C4A3A)],
        )
      : null,
  borderRadius: BorderRadius.only(
    topLeft: const Radius.circular(16),
    topRight: const Radius.circular(16),
    bottomLeft: Radius.circular(sent ? 16 : 4),
    bottomRight: Radius.circular(sent ? 4 : 16),
  ),
);

String _friendlyDataError(Object error) {
  final message = error.toString();
  if (message.contains('failed-precondition') && message.contains('index')) {
    return 'This chat query needs its Firestore index. Deploy firestore.indexes.json and try again.';
  }
  if (message.contains('permission-denied')) {
    return 'Firebase denied this request. Check that you are signed in and the security rules are deployed.';
  }
  return 'Could not load HayChat data. Please try again.';
}

void _showDataError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_friendlyDataError(error))));
}

String _formatConversationTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final now = DateTime.now();
  if (now.difference(dateTime).inDays == 0) return _clockTime(dateTime);
  if (now.difference(dateTime).inDays == 1) return 'Yesterday';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year % 100}';
}

String _formatMessageTime(DateTime? dateTime) {
  if (dateTime == null) return 'Sending...';
  return _clockTime(dateTime);
}

String _clockTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
