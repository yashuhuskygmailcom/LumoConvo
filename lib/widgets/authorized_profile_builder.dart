import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/user_service.dart';

class AuthorizedProfileBuilder extends StatefulWidget {
  const AuthorizedProfileBuilder({
    required this.userId,
    required this.builder,
    super.key,
  });

  final String userId;
  final Widget Function(BuildContext context, AppUser? profile) builder;

  @override
  State<AuthorizedProfileBuilder> createState() =>
      _AuthorizedProfileBuilderState();
}

class _AuthorizedProfileBuilderState extends State<AuthorizedProfileBuilder> {
  late Stream<AppUser?> _profile = _watchProfile();

  Stream<AppUser?> _watchProfile() {
    return UserService.instance.watchUser(widget.userId);
  }

  @override
  void didUpdateWidget(covariant AuthorizedProfileBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _profile = _watchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snapshot) => widget.builder(context, snapshot.data),
    );
  }
}
