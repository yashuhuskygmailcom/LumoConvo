import 'dart:async';

import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../theme/haychat_theme.dart';
import '../widgets/hay_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.autoAdvance = true});

  final bool autoAdvance;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoAdvance) {
      _timer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, HayRoutes.onboarding);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.35),
                radius: .8,
                colors: [Color(0x1714A15B), Colors.transparent],
              ),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HayLogo(),
                SizedBox(height: 12),
                Text(
                  'CHAT SIMPLY  ·  STAY CONNECTED',
                  style: TextStyle(
                    color: HayColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PageDot(active: true),
                SizedBox(width: 6),
                _PageDot(),
                SizedBox(width: 6),
                _PageDot(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: active ? 22 : 6,
    height: 6,
    decoration: BoxDecoration(
      color: active ? HayColors.gold : HayColors.hairlineSoft,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const HayTitle(
            'Welcome to HayChat',
            subtitle:
                'Simple, fast, and secure messaging for everyone — with a little more warmth.',
          ),
          const SizedBox(height: 30),
          const _WelcomeCarousel(),
          const Spacer(flex: 2),
          HayPrimaryButton(
            label: 'Get Started',
            onPressed: () => Navigator.pushNamed(context, HayRoutes.signUp),
          ),
          const SizedBox(height: 17),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, HayRoutes.signIn),
              child: const Text(
                'I already have an account',
                style: TextStyle(color: HayColors.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCarousel extends StatefulWidget {
  const _WelcomeCarousel();

  @override
  State<_WelcomeCarousel> createState() => _WelcomeCarouselState();
}

class _WelcomeCarouselState extends State<_WelcomeCarousel> {
  static const _slides = [
    ('assets/images/Welcome.png', 'Chat simply and stay connected'),
    ('assets/images/solo.png', 'Build your personal network'),
    ('assets/images/group.png', 'Connect with your community'),
  ];

  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: _slides.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Semantics(
                label: slide.$2,
                image: true,
                child: Image.asset(
                  slide.$1,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == _slides.length - 1 ? 0 : 6,
              ),
              child: _PageDot(active: index == _currentPage),
            ),
          ),
        ),
      ],
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await operation();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (mounted) _showError(context, AuthService.instance.messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _run(
      () => AuthService.instance.signInWithEmail(
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HayBackButton(),
              const SizedBox(height: 8),
              const HayTitle(
                'Welcome back',
                subtitle: 'Sign in to pick up where you left off.',
              ),
              const SizedBox(height: 30),
              HayField(
                label: 'Email',
                controller: _email,
                hint: 'you@gmail.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _emailValidator,
              ),
              const SizedBox(height: 17),
              HayField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: _passwordValidator,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          HayRoutes.forgotPassword,
                        ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: HayColors.goldSoft, fontSize: 11),
                  ),
                ),
              ),
              HayPrimaryButton(
                label: _loading ? 'Signing In...' : 'Sign In',
                onPressed: _loading ? null : _submit,
              ),
              const _AuthDivider(),
              _SocialButton(
                label: 'Continue with Google',
                onTap: _loading
                    ? null
                    : () => _run(AuthService.instance.signInWithGoogle),
              ),
              const SizedBox(height: 20),
              _AuthSwitch(
                text: 'New to HayChat? ',
                action: 'Create an account',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, HayRoutes.signUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.registerWithEmail(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (mounted) _showError(context, AuthService.instance.messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (mounted) _showError(context, AuthService.instance.messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HayBackButton(),
              const SizedBox(height: 4),
              const HayTitle(
                'Create account',
                subtitle: 'Your profile comes right after email verification.',
              ),
              const SizedBox(height: 28),
              HayField(
                label: 'Email',
                controller: _email,
                hint: 'you@gmail.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              HayField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: _passwordValidator,
              ),
              const SizedBox(height: 16),
              HayField(
                label: 'Confirm Password',
                controller: _confirmation,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              HayPrimaryButton(
                label: _loading ? 'Creating Account...' : 'Sign Up',
                onPressed: _loading ? null : _submit,
              ),
              const _AuthDivider(),
              _SocialButton(
                label: 'Continue with Google',
                onTap: _loading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 18),
              _AuthSwitch(
                text: 'Already have an account? ',
                action: 'Sign in',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, HayRoutes.signIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _verificationTimer;
  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _checking = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerification(silent: true),
    );
    _startResendTimer();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);
    try {
      final user = await AuthService.instance.refreshCurrentUser();
      if (user?.emailVerified ?? false) {
        _verificationTimer?.cancel();
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
      } else if (!silent && mounted) {
        _showError(
          context,
          'Not verified yet. Open the email link, then try again.',
        );
      }
    } catch (error) {
      if (!silent && mounted) {
        _showError(context, AuthService.instance.messageFor(error));
      }
    } finally {
      if (!silent && mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0) return;
    setState(() => _resending = true);
    try {
      await AuthService.instance.resendEmailVerification();
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent again.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(context, AuthService.instance.messageFor(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _changeAccount() async {
    await AuthService.instance.signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? 'your email';
    return HayScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const HayTitle(
            'Verify your email',
            subtitle: 'We sent a secure verification link to your inbox.',
          ),
          const Spacer(),
          const _EmailVerificationIllustration(),
          const SizedBox(height: 30),
          Center(
            child: Text(
              email,
              style: const TextStyle(
                color: HayColors.goldSoft,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Open the message from Firebase, tap the verification link, then return here. HayChat also checks automatically every few seconds.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          HayPrimaryButton(
            label: _checking ? 'Checking...' : 'I Verified My Email',
            onPressed: _checking ? null : _checkVerification,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _resendSeconds == 0 && !_resending ? _resend : null,
              child: Text(
                _resendSeconds > 0
                    ? 'Resend in 00:${_resendSeconds.toString().padLeft(2, '0')}'
                    : _resending
                    ? 'Sending...'
                    : 'Resend verification email',
                style: const TextStyle(color: HayColors.goldSoft, fontSize: 11),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _changeAccount,
              child: const Text(
                'Use a different account',
                style: TextStyle(color: HayColors.muted, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailVerificationIllustration extends StatelessWidget {
  const _EmailVerificationIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 130,
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HayColors.elevated, HayColors.card],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HayColors.hairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x334C7A5C),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: HayColors.goldSoft,
              size: 54,
            ),
          ),
          Positioned(
            right: -12,
            bottom: -12,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [HayColors.goldSoft, HayColors.gold],
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF23180B),
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendPasswordReset(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent. Please check your email.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(context, AuthService.instance.messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HayScaffold(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HayBackButton(),
              const HayTitle(
                'Forgot password?',
                subtitle:
                    "Enter your email and we'll send you a link to reset your password.",
              ),
              const SizedBox(height: 38),
              const _EmailVerificationIllustration(),
              const SizedBox(height: 48),
              HayField(
                label: 'Email',
                controller: _email,
                hint: 'you@gmail.com',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: 20),
              HayPrimaryButton(
                label: _loading ? 'Sending...' : 'Send Reset Link',
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 20),
              _AuthSwitch(
                text: 'Remember your password? ',
                action: 'Sign in',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider(color: HayColors.hairlineSoft)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR CONTINUE WITH',
              style: TextStyle(
                color: HayColors.muted,
                fontSize: 9,
                letterSpacing: .8,
              ),
            ),
          ),
          Expanded(child: Divider(color: HayColors.hairlineSoft)),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: HayColors.elevated,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: HayColors.ivoryDim, fontSize: 12),
          ),
        ),
      ),
    ),
  );
}

class _AuthSwitch extends StatelessWidget {
  const _AuthSwitch({
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            TextSpan(
              text: action,
              style: const TextStyle(
                color: HayColors.goldSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        style: const TextStyle(color: HayColors.muted, fontSize: 11),
      ),
    ),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String? _emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email address';
  }
  return null;
}

String? _passwordValidator(String? value) {
  if ((value ?? '').length < 6) return 'Use at least 6 characters';
  return null;
}
