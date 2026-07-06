import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../repositories/auth_repository.dart';
import '../widgets/auth_scaffold.dart';

/// Recebe o e-mail, o token de 6 dígitos e a nova senha, e chama
/// `POST /api/reset-password`. Em sucesso, devolve o usuário ao login.
///
/// Pode ser aberta diretamente (via "Já tenho um código") ou após o envio
/// do código em [ForgotPasswordScreen] — o e-mail é pré-preenchido via
/// [GoRouterState.extra].
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _senha = TextEditingController();
  final _senhaConfirm = TextEditingController();
  bool _loading = false;
  bool _obscureSenha = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialEmail?.trim();
    if (init != null && init.isNotEmpty) {
      _email.text = init;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _senha.dispose();
    _senhaConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<AuthRepository>();
      final msg = await repo.resetPassword(
        email: _email.text.trim(),
        token: _token.text.trim(),
        senha: _senha.text,
        senhaConfirmation: _senhaConfirm.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(msg),
        ),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.lock_open_rounded,
      titulo: 'Defina sua nova senha',
      subtitulo: 'Cole o código de 6 dígitos que enviamos para o seu e-mail '
          'e escolha uma senha nova com pelo menos 8 caracteres.',
      onBack: _loading
          ? null
          : () => context.canPop() ? context.pop() : context.go('/login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Informe o e-mail';
                }
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _token,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              enabled: !_loading,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos',
                prefixIcon: Icon(Icons.vpn_key_outlined),
                counterText: '',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Informe o código recebido por e-mail';
                if (t.length != 6) return 'O código deve ter 6 dígitos';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senha,
              obscureText: _obscureSenha,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                helperText: 'Pelo menos 8 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscureSenha ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _obscureSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureSenha = !_obscureSenha),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Senha com pelo menos 8 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senhaConfirm,
              obscureText: _obscureConfirm,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loading ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Confirme a nova senha';
                }
                if (v != _senha.text) return 'As senhas não conferem';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Redefinir senha'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.go('/login'),
              child: const Text('Voltar ao login'),
            ),
          ],
        ),
      ),
    );
  }
}
