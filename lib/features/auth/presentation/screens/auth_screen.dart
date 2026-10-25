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
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted && widget.controller.user != null && !_closed) {
      _closed = true;
      _password.clear();
      _confirmation.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _switchMode() {
    if (widget.controller.isBusy) return;
    FocusScope.of(context).unfocus();
    _password.clear();
    _confirmation.clear();
    widget.controller.beginSignIn();
    setState(() {
      _register = !_register;
      _showPassword = false;
    });
  }

  Future<void> _submit() async {
    final auth = widget.controller;
    if (auth.isBusy || !auth.isConfigured) return;
    FocusScope.of(context).unfocus();
    final success = _register
        ? await auth.signUp(_email.text, _password.text, _confirmation.text)
        : await auth.signIn(_email.text, _password.text);
    if (success && mounted) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final auth = widget.controller;
      final theme = Theme.of(context);
      final enabled = auth.isConfigured && !auth.isBusy;
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
                        _register ? 'Hesap oluştur' : 'Hesabına giriş yap',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        _register ? 'Etkinliklerini kendi hesabında sakla.' : 'Kaydettiğin etkinliklere kaldığın yerden devam et.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      TextField(
                        key: const ValueKey('email-input'),
                        controller: _email,
                        enabled: enabled,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          hintText: 'ornek@eposta.com',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('password-input'),
                        controller: _password,
                        enabled: enabled,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: _register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_register) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          helperText: _register
                              ? 'En az 8 karakter. Sunucunun parola kuralları geçerlidir.'
                              : null,
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Şifreyi gizle'
                                : 'Şifreyi göster',
                            onPressed: enabled
                                ? () => setState(
                                    () => _showPassword = !_showPassword,
                                  )
                                : null,
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_register) ...[
                        const SizedBox(height: AppSpacing.medium),
                        TextField(
                          key: const ValueKey('password-confirmation-input'),
                          controller: _confirmation,
                          enabled: enabled,
                          obscureText: !_showPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Şifre tekrar',
                          ),
                        ),
                      ],
                      if (!auth.isConfigured || auth.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            !auth.isConfigured
                                ? 'Hesap bağlantısı şu anda kullanılamıyor. Etkinlikleri giriş yapmadan keşfedebilirsin.'
                                : auth.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.page),
                      FilledButton(
                        onPressed: enabled ? _submit : null,
                        child: auth.isBusy
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(_register ? 'Hesap Oluştur' : 'Giriş Yap'),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      TextButton(
                        onPressed: enabled ? _switchMode : null,
                        child: Text(
                          _register
                              ? 'Zaten hesabın var mı? Giriş Yap'
                              : 'Hesabın yok mu? Kayıt Ol',
                        ),
                      ),
                      if (!auth.isConfigured)
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Keşfet’e dön'),
                        ),
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
