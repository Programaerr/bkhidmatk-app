import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'push_key.dart';
import 'raised_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
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
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SheetHeader(title: tr('اختر المحافظة', 'Choose your province')),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: iraqCities.length,
                itemBuilder: (_, i) {
                  final city = iraqCities[i];
                  return ListTile(
                    title: Text(cityLabel(city)),
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
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('إنشاء حساب', 'Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RequiredFieldLabel(tr('الاسم الكامل', 'Full name'), controller: _name),
                RaisedField(
                  controller: _name,
                  hint: tr('مثال: أحمد سعد', 'Example: Ahmed Saad'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v.trim().length < 3 ? tr('أدخل الاسم الكامل', 'Enter your full name') : null,
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel(tr('رقم الهاتف', 'Phone number'), controller: _phone),
                RaisedField(
                  controller: _phone,
                  hint: '07XX XXX XXXX',
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [IraqiPhoneFormatter()],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  onTyped: _clearSubmitError,
                  validator: (v) {
                    if (v.trim().isEmpty) return tr('أدخل رقم الهاتف', 'Enter the phone number');
                    if (!validIraqiPhone(phoneFromInput(v))) {
                      return tr('رقم غير صالح (11 رقم يبدأ بـ 07)', 'Invalid number (11 digits starting with 07)');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                FieldLabel(tr('المحافظة', 'Province'), required_: true, filled: _city != null),
                RaisedPicker(
                  value: _city == null ? null : cityLabel(_city!),
                  hint: tr('اختر المحافظة', 'Choose the province'),
                  emptyError: tr('اختر محافظتك', 'Choose your province'),
                  open: _pickingCity,
                  onTap: _pickCity,
                ),
                const SizedBox(height: 14),
                FieldLabel(tr('العنوان التفصيلي', 'Detailed address')),
                RaisedField(
                  controller: _address,
                  hint: tr('المنطقة، الشارع، أقرب نقطة دالة', 'Area, street, nearest landmark'),
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel(tr('كلمة المرور', 'Password'), controller: _password),
                RaisedField(
                  controller: _password,
                  hint: tr('6 أحرف على الأقل', 'At least 6 characters'),
                  obscureText: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) => v.length < 6 ? tr('كلمة المرور 6 أحرف على الأقل', 'The password must be at least 6 characters') : null,
                ),
                const SizedBox(height: 14),
                RequiredFieldLabel(tr('تأكيد كلمة المرور', 'Confirm password'), controller: _confirm),
                RaisedField(
                  controller: _confirm,
                  hint: tr('أعد كتابة كلمة المرور', 'Type the password again'),
                  obscureText: true,
                  clearErrorWith: _password,
                  validator: (v) => v != _password.text ? tr('كلمتا المرور غير متطابقتين', "The passwords don't match") : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ],
                const SizedBox(height: 19),
                PushKeyButton(
                  label: tr('متابعة', 'Continue'),
                  onPressed: _submit,
                  loading: _loading,
                  yellow: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
