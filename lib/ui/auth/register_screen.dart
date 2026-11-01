import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'push_key.dart';
import 'raised_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialPhone});

  /// الرقم المُدخل في الشاشة الأولى حتى لا يُعاد كتابته.
  final String? initialPhone;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _city;
  bool _obscure = true;
  bool _pickingCity = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clearSubmitError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _pickCity() async {
    setState(() => _pickingCity = true);
    final selected = await showAppSheet<String>(
      context,
      builder: (ctx) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SheetHeader(title: 'اختر المحافظة'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: iraqCities.length,
                itemBuilder: (_, i) {
                  final city = iraqCities[i];
                  return ListTile(
                    title: Text(city),
                    trailing: city == _city
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, city),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _pickingCity = false;
      if (selected != null) _city = selected;
    });
  }

  Future<void> _submit() async {
    if (!validateAndShowFirstError(_formKey.currentState!)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context.read<AppState>().register(
          name: _name.text,
          phone: phoneFromInput(_phone.text),
          password: _password.text,
          city: _city,
          address: _address.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RequiredFieldLabel('الاسم الكامل', controller: _name),
                RaisedField(
                  controller: _name,
                  hint: 'مثال: أحمد سعد',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v.trim().length < 3 ? 'أدخل الاسم الكامل' : null,
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel('رقم الهاتف', controller: _phone),
                RaisedField(
                  controller: _phone,
                  hint: '07XX XXX XXXX',
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [IraqiPhoneFormatter()],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  onTyped: _clearSubmitError,
                  validator: (v) {
                    if (v.trim().isEmpty) return 'أدخل رقم الهاتف';
                    if (!validIraqiPhone(phoneFromInput(v))) {
                      return 'رقم غير صالح (11 رقم يبدأ بـ 07)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                FieldLabel('المحافظة', required_: true, filled: _city != null),
                RaisedPicker(
                  value: _city,
                  hint: 'اختر المحافظة',
                  emptyError: 'اختر محافظتك',
                  open: _pickingCity,
                  onTap: _pickCity,
                ),
                const SizedBox(height: 14),
                const FieldLabel('العنوان التفصيلي'),
                RaisedField(
                  controller: _address,
                  hint: 'المنطقة، الشارع، أقرب نقطة دالة',
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel('كلمة المرور', controller: _password),
                RaisedField(
                  controller: _password,
                  hint: '6 أحرف على الأقل',
                  obscureText: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) => v.length < 6 ? 'كلمة المرور 6 أحرف على الأقل' : null,
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel('تأكيد كلمة المرور', controller: _confirm),
                RaisedField(
                  controller: _confirm,
                  hint: 'أعد كتابة كلمة المرور',
                  obscureText: true,
                  clearErrorWith: _password,
                  validator: (v) => v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 19),
                PushKeyButton(
                  label: 'إنشاء الحساب',
                  onPressed: _submit,
                  loading: _loading,
                  yellow: true,
                ),
                const SizedBox(height: 7),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('لديك حساب؟', style: theme.textTheme.bodySmall),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        child: const Text('تسجيل الدخول'),
                      ),
                    ],
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
