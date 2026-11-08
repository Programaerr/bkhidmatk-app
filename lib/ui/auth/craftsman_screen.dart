import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'push_key.dart';
import 'raised_field.dart';

/// صفحة الحرفي: يملأ معلوماته الشخصية وخبرته ويرسلها إلى الشركة.
class CraftsmanScreen extends StatefulWidget {
  const CraftsmanScreen({super.key});

  @override
  State<CraftsmanScreen> createState() => _CraftsmanScreenState();
}

class _CraftsmanScreenState extends State<CraftsmanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _trade = TextEditingController();
  final _years = TextEditingController();
  final _about = TextEditingController();
  String? _city;
  bool _pickingCity = false;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    _address.dispose();
    _trade.dispose();
    _years.dispose();
    _about.dispose();
    super.dispose();
  }

  void _backAsCustomer() => Navigator.of(context).popUntil((route) => route.isFirst);

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
    final repo = context.read<AppState>().repo;
    final phone = phoneFromInput(_phone.text);
    try {
      await _send(repo, phone);
    } catch (_) {
      // فشل الإرسال لا يترك الزر يدور للأبد، فيمكن إعادة المحاولة.
      if (mounted) setState(() => _loading = false);
      rethrow;
    }
  }

  Future<void> _send(Repository repo, String phone) async {
    if (await repo.hasPendingApplication(phone)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('يوجد طلب قيد المراجعة بهذا الرقم', 'There is already a request under review with this number');
      });
      return;
    }
    final address = _address.text.trim();
    final about = _about.text.trim();
    await repo.createApplication(
      CraftsmanApplication(
        name: _name.text.trim(),
        phone: phone,
        age: int.parse(westernDigits(_age.text)),
        city: _city!,
        address: address.isEmpty ? null : address,
        trade: _trade.text.trim(),
        experienceYears: int.parse(westernDigits(_years.text)),
        about: about.isEmpty ? null : about,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  String? _checkNumber(String value, int min, int max, String message) {
    final number = int.tryParse(westernDigits(value));
    return number == null || number < min || number > max ? message : null;
  }

  Widget _backButton() => PushKeyButton(label: tr('عودة كزبون', 'Back as a customer'), onPressed: _backAsCustomer);

  Widget _sentMessage(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 68, color: AppColors.success),
            const SizedBox(height: 14),
            Text(tr('وصل طلبك إلى الشركة', 'Your request reached the company'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              tr('سنراجع معلوماتك ونتواصل معك على رقمك.', "We'll review your information and contact you on your number."),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 26),
            _backButton(),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
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
              validator: (v) =>
                  validIraqiPhone(phoneFromInput(v)) ? null : tr('رقم غير صالح (11 رقم يبدأ بـ 07)', 'Invalid number (11 digits starting with 07)'),
            ),
            const SizedBox(height: 14),
            RequiredFieldLabel(tr('العمر', 'Age'), controller: _age),
            RaisedField(
              controller: _age,
              hint: tr('مثال: 28', 'Example: 28'),
              keyboardType: TextInputType.number,
              inputFormatters: const [MaxDigitsFormatter(2)],
              validator: (v) => _checkNumber(v, 16, 80, tr('أدخل عمراً صحيحاً', 'Enter a valid age')),
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
            RequiredFieldLabel(tr('المهنة', 'Trade'), controller: _trade),
            RaisedField(
              controller: _trade,
              hint: tr('مثال: كهربائي، سباك، صباغ', 'Example: electrician, plumber, painter'),
              validator: (v) => v.trim().length < 2 ? tr('أدخل مهنتك', 'Enter your trade') : null,
            ),
            const SizedBox(height: 14),
            RequiredFieldLabel(tr('سنوات الخبرة', 'Years of experience'), controller: _years),
            RaisedField(
              controller: _years,
              hint: tr('مثال: 5', 'Example: 5'),
              keyboardType: TextInputType.number,
              inputFormatters: const [MaxDigitsFormatter(2)],
              validator: (v) => _checkNumber(v, 0, 60, tr('أدخل عدد سنوات صحيحاً', 'Enter a valid number of years')),
            ),
            const SizedBox(height: 14),
            FieldLabel(tr('نبذة عن خبرتك', 'About your experience')),
            RaisedField(
              controller: _about,
              hint: tr('الأعمال التي أتقنها وأين عملت سابقاً', "The work you're good at and where you worked before"),
              minLines: 3,
              maxLines: 6,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 19),
            PushKeyButton(
              label: tr('إرسال الطلب إلى الشركة', 'Send the request to the company'),
              onPressed: _submit,
              loading: _loading,
              yellow: true,
            ),
            const SizedBox(height: 4),
            _backButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('التقديم كحرفي', 'Apply as a craftsman')),
      body: SafeArea(child: _sent ? _sentMessage(theme) : _form()),
    );
  }
}
