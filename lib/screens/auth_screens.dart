import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/soft_symbols.dart';
import '../widgets/bloomy_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  Timer? _verificationAutoCheckTimer;
  bool _isCheckingVerification = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onCredentialsChanged);
    _passCtrl.addListener(_onCredentialsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final auth = context.read<AuthProvider>();
      final pendingEmail = auth.verificationEmail;
      if ((pendingEmail ?? '').isNotEmpty && _emailCtrl.text.trim().isEmpty) {
        _emailCtrl.text = pendingEmail!.trim();
      }
    });
  }

  @override
  void dispose() {
    _verificationAutoCheckTimer?.cancel();
    _resendCooldownTimer?.cancel();
    _emailCtrl
      ..removeListener(_onCredentialsChanged)
      ..dispose();
    _passCtrl
      ..removeListener(_onCredentialsChanged)
      ..dispose();
    super.dispose();
  }

  void _onCredentialsChanged() {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _stopVerificationAutoCheck();
    }
  }

  void _startResendCooldown([int seconds = 45]) {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  void _startVerificationAutoCheck() {
    _verificationAutoCheckTimer?.cancel();
    _verificationAutoCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerifiedStatus(silent: true, fromAutoCheck: true),
    );
  }

  void _stopVerificationAutoCheck() {
    _verificationAutoCheckTimer?.cancel();
    _verificationAutoCheckTimer = null;
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }

    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email, password);
    if (!mounted) return;
    if (ok) {
      _stopVerificationAutoCheck();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      final errorMsg =
          auth.error ?? 'Login failed. Check your email and password.';
      setState(() => _error = errorMsg);
      if (auth.requiresEmailVerification) {
        _startResendCooldown();
        _startVerificationAutoCheck();
      }
    }
  }

  Future<void> _checkVerifiedStatus({
    bool silent = false,
    bool fromAutoCheck = false,
  }) async {
    if (_isCheckingVerification) {
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      if (!silent) {
        setState(
          () => _error =
              'Enter your email and password first, then check verification.',
        );
      }
      return;
    }

    _isCheckingVerification = true;
    final auth = context.read<AuthProvider>();
    final ok = await auth.checkEmailVerificationStatus(
      email,
      password,
      loginIfVerified: true,
      silentWhenUnverified: silent,
    );
    _isCheckingVerification = false;

    if (!mounted) {
      return;
    }

    if (ok) {
      _stopVerificationAutoCheck();
      if (!fromAutoCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified. Welcome back!')),
        );
      }
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    if (!silent) {
      setState(() {
        _error = auth.error ?? 'Email is not verified yet.';
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(
        () => _error =
            'Enter your email and password first, then tap resend verification.',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.resendEmailVerification(email, password);
    if (!mounted) {
      return;
    }

    if (ok) {
      _startResendCooldown();
      _startVerificationAutoCheck();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.requiresEmailVerification
                ? 'Verification email sent. Check inbox/spam.'
                : (auth.error ?? 'Email already verified. Please sign in.'),
          ),
        ),
      );
      if (!auth.requiresEmailVerification) {
        setState(() => _error = auth.error);
      }
    } else {
      setState(
          () => _error = auth.error ?? 'Unable to resend verification email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showVerificationActions = auth.requiresEmailVerification ||
        ((_error ?? '').toLowerCase().contains('verify'));
    final isResendOnCooldown = _resendCooldownSeconds > 0;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cream,
                AppColors.lavenderLight,
                Color(0xFFFFF0F5)
              ]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Center(child: BloomyLogo(size: 70, showTagline: true)),
                const SizedBox(height: 48),
                Text('Welcome back ${SoftSymbols.blossom}',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text('Sign in to your safe space',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (showVerificationActions) ...[
                  const SizedBox(height: 16),
                  _VerificationPendingBanner(
                    email: auth.verificationEmail,
                    isAutoChecking: _verificationAutoCheckTimer != null,
                  ),
                ],
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: AppColors.deepPink),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.deepPink),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textLight),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.softPink.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.deepPink)),
                  ),
                ],
                if (showVerificationActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (auth.isLoading || _isCheckingVerification)
                              ? null
                              : () => _checkVerifiedStatus(),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Check verified status'),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: (auth.isLoading || isResendOnCooldown)
                          ? null
                          : _resendVerificationEmail,
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        isResendOnCooldown
                            ? 'Resend in ${_resendCooldownSeconds}s'
                            : 'Resend verification email',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/signup'),
                    child: const Text(
                      "Don't have an account? Join Bloomy ${SoftSymbols.blossom}",
                        style: TextStyle(color: AppColors.textMed)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _VerificationPendingBanner extends StatelessWidget {
  final String? email;
  final bool isAutoChecking;

  const _VerificationPendingBanner({
    required this.email,
    required this.isAutoChecking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavenderLight.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.deepPink.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.deepPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email Verification Pending',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email == null || email!.isEmpty
                      ? 'Open your inbox and click the verification link, then return here.'
                      : 'We sent a verification link to $email. Open inbox/spam, verify, then return here.',
                  style: const TextStyle(
                    color: AppColors.textMed,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (isAutoChecking) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Auto-check is on. You will continue automatically after verification.',
                    style: TextStyle(
                      color: AppColors.deepPink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  Future<void> _signup() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    // Validation
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name');
      return;
    }
    if (username.isEmpty) {
      setState(() => _error = 'Please choose a username');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.signup(email, username, name, password);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification email sent to ${auth.verificationEmail ?? email}. Please verify, then sign in.',
          ),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() => _error = auth.error ?? 'Signup failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.lavenderLight,
                AppColors.cream,
                Color(0xFFFFF0F5)
              ]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Center(child: BloomyLogo(size: 60)),
                const SizedBox(height: 36),
                Text('Join Bloomy ${SoftSymbols.blossom}',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text('Your safe space is waiting',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppColors.deepPink))),
                const SizedBox(height: 16),
                TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email_rounded,
                            color: AppColors.deepPink))),
                const SizedBox(height: 16),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppColors.deepPink))),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 chars)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.deepPink),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textLight),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.softPink.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.deepPink, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _signup,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                      : const Text('Create my space'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Already blooming? Sign in',
                        style: TextStyle(color: AppColors.textMed)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
