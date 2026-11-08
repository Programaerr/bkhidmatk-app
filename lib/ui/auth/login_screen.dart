import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import 'account_type_screen.dart';
import 'auth_route.dart';
import 'push_key.dart';
import 'raised_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
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
    final err = await context
        .read<AppState>()
        .login(phoneFromInput(_phone.text), _password.text);
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
    final usesCloudAuth = context.watch<AppState>().usesCloudAuth;
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('تسجيل الدخول', 'Log in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RequiredFieldLabel(tr('رقم الهاتف', 'Phone number'), controller: _phone),
                    RaisedField(
                      controller: _phone,
                      hint: '07XX XXX XXXX',
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [IraqiPhoneFormatter()],
                      textDirection: TextDirection.ltr,
                      textAlign: appEnglish ? TextAlign.left : TextAlign.right,
                      onTyped: _clearLoginError,
                      validator: (v) {
                        if (v.trim().isEmpty) return tr('أدخل رقم الهاتف', 'Enter the phone number');
                        if (!validIraqiPhone(phoneFromInput(v))) {
                          return tr('رقم غير صالح (11 رقم يبدأ بـ 07)', 'Invalid number (11 digits starting with 07)');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    RequiredFieldLabel(tr('كلمة المرور', 'Password'), controller: _password),
                    RaisedField(
                      controller: _password,
                      hint: tr('أدخل كلمة المرور', 'Enter the password'),
                      obscureText: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onTyped: _clearLoginError,
                      onSubmitted: (_) => _submit(),
                      validator: (v) =>
                          v.length < 6 ? tr('كلمة المرور 6 أحرف على الأقل', 'The password must be at least 6 characters') : null,
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
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: .2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 17),
              PushKeyButton(
                label: tr('تسجيل الدخول', 'Log in'),
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
                    Text(tr('ليس لديك حساب؟', "Don't have an account?"), style: theme.textTheme.bodySmall),
                    TextButton(
                      onPressed: () => openAuthPage(
                        context,
                        const AccountTypeScreen(),
                        night: theme.brightness == Brightness.dark,
                      ),
                      child: Text(tr('إنشاء حساب جديد', 'Create a new account')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!usesCloudAuth)
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
                              tr('دخول تجريبي سريع', 'Quick demo login'),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PushKeyButton(
                              label: tr('زبون', 'Customer'),
                              compact: true,
                              onPressed: _loading
                                  ? null
                                  : () => _quick('07701234567', '123456'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PushKeyButton(
                              label: tr('مدير', 'Admin'),
                              compact: true,
                              onPressed: _loading
                                  ? null
                                  : () => _quick('07700000000', 'admin123'),
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
