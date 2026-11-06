import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/contact_invite.dart';
import '../models/qr_identity.dart';
import '../services/contact_service.dart';
import '../services/qr_service.dart';
import '../theme/haychat_theme.dart';
import '../widgets/hay_widgets.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  late Future<QrIdentity> _identity = QrService.instance.ensureCurrentQr();

  void _retry() {
    final identity = QrService.instance.ensureCurrentQr();
    setState(() {
      _identity = identity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HayBackButton(),
          const HayTitle(
            'My QR Code',
            subtitle:
                'Let someone scan this code to send you a contact invite.',
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Center(
              child: FutureBuilder<QrIdentity>(
                future: _identity,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator(
                      color: HayColors.gold,
                      strokeWidth: 2,
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _QrError(onRetry: _retry);
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44C6A15B),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: snapshot.data!.payload,
                          size: 230,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: HayColors.deep,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: HayColors.deep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Only people you approve become contacts.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final ImagePicker _imagePicker = ImagePicker();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final value = _firstPayload(capture.barcodes);
    if (value == null) return;
    await _processPayload(value);
  }

  String? _firstPayload(Iterable<Barcode> barcodes) {
    for (final barcode in barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _payloadFromImage(BarcodeCapture? capture) {
    final values = <String>{};
    for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) values.add(value);
    }
    if (values.isEmpty) {
      throw const QrFlowException('No QR code was found in that image.');
    }

    final hayChatValues = values
        .where((value) => QrIdentity.tokenFromPayload(value) != null)
        .toList();
    if (hayChatValues.length == 1) return hayChatValues.single;
    if (values.length == 1) return values.single;
    throw const QrFlowException(
      'Multiple QR codes were found. Choose an image with one HayChat QR code.',
    );
  }

  Future<void> _pickQrImage() async {
    if (_processing) return;
    setState(() => _processing = true);
    var routePopped = false;
    try {
      await _stopCamera();
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (!mounted || image == null) return;

      final capture = await _controller.analyzeImage(
        image.path,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;
      routePopped = await _resolveConfirmAndSend(_payloadFromImage(capture));
    } catch (error) {
      _showScanError(error);
    } finally {
      await _resumeScanner(routePopped: routePopped);
    }
  }

  Future<void> _processPayload(String payload) async {
    if (_processing) return;
    setState(() => _processing = true);
    var routePopped = false;
    try {
      await _stopCamera();
      routePopped = await _resolveConfirmAndSend(payload);
    } catch (error) {
      _showScanError(error);
    } finally {
      await _resumeScanner(routePopped: routePopped);
    }
  }

  Future<bool> _resolveConfirmAndSend(String payload) async {
    final profile = await QrService.instance.resolvePayload(payload);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (profile.ownerId == currentUid) {
      throw const ContactFlowException('This is your own QR code.');
    }
    if (!mounted) return false;

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: HayColors.card,
        title: const Text(
          'Send contact invite?',
          style: TextStyle(fontFamily: HayTheme.displayFont),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HayAvatar(
              initials: _initialsFor(profile.displayName),
              size: 70,
              photoUrl: profile.photoUrl,
            ),
            const SizedBox(height: 14),
            Text(profile.displayName),
            const SizedBox(height: 4),
            Text(
              profile.status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return false;

    await ContactService.instance.sendInvite(profile);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to ${profile.displayName}.')),
    );
    Navigator.pop(context);
    return true;
  }

  Future<void> _stopCamera() async {
    try {
      await _controller.stop();
    } on MobileScannerException {
      // Gallery analysis does not require an active camera.
    }
  }

  Future<void> _resumeScanner({required bool routePopped}) async {
    if (!mounted || routePopped) return;
    setState(() => _processing = false);
    try {
      await _controller.start();
    } on MobileScannerException {
      // The scanner widget will continue showing its camera error state.
    }
  }

  void _showScanError(Object error) {
    if (!mounted) return;
    final message = switch (error) {
      ContactFlowException() => error.message,
      QrFlowException() => error.message,
      MobileScannerBarcodeException() =>
        'Could not decode a QR code from that image.',
      UnsupportedError() =>
        'Scanning QR codes from images is not supported on this device.',
      _ => 'Could not process this QR code.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x99000000), width: 46),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: HayColors.gold, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: HayColors.card,
                    foregroundColor: HayColors.ivory,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Point the camera at a HayChat QR code or choose a saved image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _processing ? null : _pickQrImage,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: HayColors.card,
                        foregroundColor: HayColors.ivory,
                        side: const BorderSide(color: HayColors.goldSoft),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from Gallery'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_processing)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: HayColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class ContactInvitesScreen extends StatelessWidget {
  const ContactInvitesScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HayBackButton(),
          const HayTitle(
            'Contact Invites',
            subtitle: 'Accept only people you recognize.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<List<ContactInvite>>(
              stream: ContactService.instance.watchIncomingInvites(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load invites.'));
                }
                final invites = snapshot.data;
                if (invites == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: HayColors.gold,
                      strokeWidth: 2,
                    ),
                  );
                }
                if (invites.isEmpty) {
                  return const Center(
                    child: Text('No pending contact invites.'),
                  );
                }
                return ListView.separated(
                  itemCount: invites.length,
                  separatorBuilder: (_, _) => const Hairline(),
                  itemBuilder: (context, index) =>
                      _InviteTile(invite: invites[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatefulWidget {
  const _InviteTile({required this.invite});

  final ContactInvite invite;

  @override
  State<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends State<_InviteTile> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (accept) {
        await ContactService.instance.acceptInvite(widget.invite);
      } else {
        await ContactService.instance.declineInvite(widget.invite);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this invite.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          HayAvatar(
            initials: _initialsFor(invite.senderName),
            photoUrl: invite.senderPhotoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.senderName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  invite.senderStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: _loading ? null : () => _respond(false),
            icon: const Icon(Icons.close_rounded, color: HayColors.clay),
          ),
          IconButton.filled(
            tooltip: 'Accept',
            onPressed: _loading ? null : () => _respond(true),
            style: IconButton.styleFrom(
              backgroundColor: HayColors.gold,
              foregroundColor: const Color(0xFF23180B),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

class _QrError extends StatelessWidget {
  const _QrError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.qr_code_2_rounded, color: HayColors.clay, size: 52),
      const SizedBox(height: 12),
      const Text('Could not create your QR code.'),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'HC';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length.clamp(1, 2)).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
