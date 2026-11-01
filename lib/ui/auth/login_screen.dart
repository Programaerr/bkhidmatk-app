import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'push_key.dart';
import 'raised_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialPhone});

  /// الرقم المُدخل في الشاشة الأولى حتى لا يُعاد كتابته.
  final String? initialPhone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearLoginError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!validateAndShowFirstError(_formKey.currentState!)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context.read<AppState>().login(phoneFromInput(_phone.text), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _quick(String phone, String pass) async {
    _phone.text = phone;
    _password.text = pass;
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(size: 62, radius: 18),
              const SizedBox(height: 18),
              Text('أهلاً بعودتك 👋', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('سجّل دخولك لمتابعة حجوزاتك وخدماتك.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'وضع تجريبي محلي: البيانات محفوظة على هذا الجهاز فقط، ولا تتزامن مع أجهزة أخرى.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RequiredFieldLabel('رقم الهاتف', controller: _phone),
                    RaisedField(
                      controller: _phone,
                      hint: '07XX XXX XXXX',
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      onTyped: _clearLoginError,
                      validator: (v) {
                        if (v.trim().isEmpty) return 'أدخل رقم الهاتف';
                        if (!validIraqiPhone(phoneFromInput(v))) {
                          return 'رقم غير صالح (11 رقم يبدأ بـ 07)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    RequiredFieldLabel('كلمة المرور', controller: _password),
                    RaisedField(
                      controller: _password,
                      hint: 'أدخل كلمة المرور',
                      autofocus: widget.initialPhone != null,
                      obscureText: _obscure,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onTyped: _clearLoginError,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => v.length < 6 ? 'كلمة المرور 6 أحرف على الأقل' : null,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: .2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 17),
              PushKeyButton(
                label: 'تسجيل الدخول',
                onPressed: _submit,
                loading: _loading,
                yellow: true,
              ),
              const SizedBox(height: 11),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('ليس لديك حساب؟', style: theme.textTheme.bodySmall),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('إنشاء حساب جديد'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'دخول تجريبي سريع',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => _quick('07701234567', '123456'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                            child: const Text('زبون', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => _quick('07700000000', 'admin123'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                            child: const Text('مدير', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
