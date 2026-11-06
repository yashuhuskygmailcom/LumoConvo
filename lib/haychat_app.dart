import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';
import 'models/conversation.dart';
import 'routes.dart';
import 'screens/auth_screens.dart';
import 'screens/chat_screens.dart';
import 'screens/contact_screens.dart';
import 'screens/profile_screens.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';
import 'theme/haychat_theme.dart';
import 'widgets/hay_widgets.dart';

class HayChatApp extends StatelessWidget {
  const HayChatApp({required this.firebase, super.key});

  final FirebaseBootstrapResult firebase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'HayChat',
      debugShowCheckedModeBanner: false,
      theme: HayTheme.dark,
      home: firebase.isReady
          ? const _AuthGate()
          : FirebaseSetupScreen(error: firebase.error),
      routes: {
        HayRoutes.splash: (_) => const SplashScreen(),
        HayRoutes.onboarding: (_) => const OnboardingScreen(),
        HayRoutes.signIn: (_) => const SignInScreen(),
        HayRoutes.signUp: (_) => const SignUpScreen(),
        HayRoutes.verifyEmail: (_) => const EmailVerificationScreen(),
        HayRoutes.createProfile: (_) => const CreateProfileScreen(),
        HayRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        HayRoutes.newConversation: (_) => _ProtectedRoute(
          builder: (user) => NewConversationScreen(userId: user.uid),
        ),
        HayRoutes.createGroup: (_) => _ProtectedRoute(
          builder: (user) => CreateGroupScreen(userId: user.uid),
        ),
        HayRoutes.profile: (_) =>
            _ProtectedRoute(builder: (user) => ProfileScreen(authUser: user)),
        HayRoutes.settings: (_) =>
            _ProtectedRoute(builder: (_) => const SettingsScreen()),
        HayRoutes.myQr: (_) =>
            _ProtectedRoute(builder: (_) => const MyQrScreen()),
        HayRoutes.scanQr: (_) =>
            _ProtectedRoute(builder: (_) => const ScanQrScreen()),
        HayRoutes.contactInvites: (_) => _ProtectedRoute(
          builder: (user) => ContactInvitesScreen(userId: user.uid),
        ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == HayRoutes.conversation ||
            settings.name == HayRoutes.chat) {
          final arguments = settings.arguments;
          if (arguments is! ChatRouteArguments) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const _InvalidRouteScreen(),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _ProtectedRoute(
              builder: (user) =>
                  ChatScreen(arguments: arguments, currentUserId: user.uid),
            ),
          );
        }
        return null;
      },
    );
  }
}

class _ProtectedRoute extends StatelessWidget {
  const _ProtectedRoute({required this.builder});

  final Widget Function(User user) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AccountSyncScreen();
        }
        if (user == null) return const OnboardingScreen();
        return builder(user);
      },
    );
  }
}

class _InvalidRouteScreen extends StatelessWidget {
  const _InvalidRouteScreen();

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.link_off_rounded,
              color: HayColors.goldSoft,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              'This chat link is invalid.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(autoAdvance: false);
        }
        final user = snapshot.data;
        if (user == null) return const OnboardingScreen();
        if (!user.emailVerified) return const EmailVerificationScreen();
        return _VerifiedTokenGate(user: user);
      },
    );
  }
}

class _VerifiedTokenGate extends StatefulWidget {
  const _VerifiedTokenGate({required this.user});

  final User user;

  @override
  State<_VerifiedTokenGate> createState() => _VerifiedTokenGateState();
}

class _VerifiedTokenGateState extends State<_VerifiedTokenGate> {
  late Future<bool> _preparation = _prepareAccount();

  Future<bool> _prepareAccount() async {
    try {
      final verified = await AuthService.instance.hasVerifiedEmailToken(
        widget.user,
      );
      if (!verified) return false;
      await AuthService.instance.ensureCurrentProfile();
      return true;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'HayChat account synchronization',
        ),
      );
      rethrow;
    }
  }

  void _retry() {
    final preparation = _prepareAccount();
    setState(() {
      _preparation = preparation;
    });
  }

  @override
  void didUpdateWidget(covariant _VerifiedTokenGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _preparation = _prepareAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _preparation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AccountSyncScreen();
        }
        if (snapshot.hasError) {
          return _AccountRecoveryScreen(onRetry: _retry);
        }
        if (snapshot.data == true) {
          return _ProfileGate(
            key: ValueKey(widget.user.uid),
            userId: widget.user.uid,
          );
        }
        return const EmailVerificationScreen();
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({required this.userId, super.key});

  final String userId;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Stream<CurrentUserProfileState> _profiles = _watchProfiles();

  Stream<CurrentUserProfileState> _watchProfiles() {
    return UserService.instance.watchCurrentUserState(widget.userId);
  }

  @override
  void didUpdateWidget(covariant _ProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _profiles = _watchProfiles();
    }
  }

  void _retry() {
    setState(() => _profiles = _watchProfiles());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CurrentUserProfileState>(
      stream: _profiles,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AccountRecoveryScreen(onRetry: _retry);
        }
        final state = snapshot.data;
        if (state == null || state.hasPendingWrites || state.isFromCache) {
          return const _AccountSyncScreen();
        }
        final profile = state.profile;
        if (profile == null || !profile.profileCompleted) {
          return CreateProfileScreen(
            key: ValueKey(profile?.id ?? 'missing-profile'),
            user: profile,
          );
        }
        return HomeScreen(currentUserId: widget.userId);
      },
    );
  }
}

class _AccountSyncScreen extends StatelessWidget {
  const _AccountSyncScreen();

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: HayColors.gold,
              strokeWidth: 2,
            ),
            const SizedBox(height: 18),
            Text(
              'Finishing account setup...',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Syncing your secure profile with Firestore.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRecoveryScreen extends StatelessWidget {
  const _AccountRecoveryScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sync_problem_rounded,
              color: HayColors.goldSoft,
              size: 48,
            ),
            const SizedBox(height: 18),
            Text(
              'Could not sync your account',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection, then retry. Your account is safe.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: HayPrimaryButton(label: 'Retry', onPressed: onRetry),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: AuthService.instance.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HayLogo(),
              const SizedBox(height: 32),
              Text(
                'Connect Firebase',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'HayChat is ready for Firebase, but this build does not contain valid native Firebase configuration.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(
                  error.toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: HayColors.clay, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
