import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _closed = false;
  bool _wasCodeSent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    final auth = widget.controller;
    if (auth.user != null && !_closed) {
      _closed = true;
      Navigator.of(context).pop();
      return;
    }
    if (auth.codeSent && !_wasCodeSent) {
      _code.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    }
    _wasCodeSent = auth.codeSent;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    await widget.controller.sendCode(_email.text);
  }

  Future<void> _verify() async {
    final success = await widget.controller.verifyCode(_code.text);
    if (!success && mounted) {
      _code.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _code.text.length,
      );
      _codeFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final auth = widget.controller;
      final theme = Theme.of(context);
      final verifying = auth.codeSent;
      final canSend =
          !auth.isBusy && auth.isConfigured && auth.resendSeconds == 0;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        verifying
                            ? 'E-postanı kontrol et'
                            : 'Hesabına giriş yap',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        verifying
                            ? '${auth.otpLength} haneli giriş kodunu gönderdiğimiz e-postada bulabilirsin.'
                            : 'Etkinliklerini kaydetmek için e-posta adresini gir.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (verifying) ...[
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          auth.email ?? '',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          'Kod gelmediyse spam klasörünü de kontrol et.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.large),
                      if (verifying)
                        TextField(
                          key: const ValueKey('otp-input'),
                          controller: _code,
                          focusNode: _codeFocus,
                          enabled: !auth.isBusy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: auth.otpLength,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            labelText: '${auth.otpLength} haneli kod',
                            counterText: '',
                          ),
                          onSubmitted: (_) {
                            if (!auth.isBusy) _verify();
                          },
                        )
                      else
                        TextField(
                          key: const ValueKey('email-input'),
                          controller: _email,
                          autofocus: auth.isConfigured,
                          enabled: !auth.isBusy && auth.isConfigured,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'E-posta adresi',
                            hintText: 'ornek@eposta.com',
                          ),
                          onSubmitted: (_) {
                            if (canSend) _send();
                          },
                        ),
                      if (!auth.isConfigured || auth.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            auth.errorMessage ??
                                auth.setupMessage ??
                                'Supabase yapılandırması eksik.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.page),
                      FilledButton(
                        onPressed: verifying
                            ? (auth.isBusy ? null : _verify)
                            : (canSend ? _send : null),
                        child: auth.isBusy
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                verifying
                                    ? 'Doğrula'
                                    : (auth.resendSeconds > 0
                                          ? 'Kod gönder (${auth.resendSeconds} sn)'
                                          : 'Kod gönder'),
                              ),
                      ),
                      if (verifying) ...[
                        const SizedBox(height: AppSpacing.small),
                        TextButton(
                          onPressed: canSend
                              ? () => auth.sendCode(auth.email!)
                              : null,
                          child: Text(
                            auth.resendSeconds > 0
                                ? 'Kodu tekrar gönder (${auth.resendSeconds} sn)'
                                : 'Kodu tekrar gönder',
                          ),
                        ),
                        TextButton(
                          onPressed: auth.isBusy
                              ? null
                              : () {
                                  _code.clear();
                                  auth.useDifferentEmail();
                                },
                          child: const Text('Farklı e-posta kullan'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
