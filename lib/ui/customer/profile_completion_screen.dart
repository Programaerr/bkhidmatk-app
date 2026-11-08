import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../auth/raised_field.dart';
import '../widgets/ui.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  String? _city;
  bool _pickingCity = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user!;
    _name.text = user.name;
    _address.text = user.address ?? '';
    _city = iraqCities.contains(user.city) ? user.city : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
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
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20)
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

  Future<void> _save() async {
    if (!validateAndShowFirstError(_formKey.currentState!)) return;
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) {
      setState(() => _error = tr('انتهت الجلسة، سجل الدخول ثم حاول مرة أخرى', 'The session ended. Log in and try again.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await state.updateProfile(user.copyWith(
        name: _name.text.trim(),
        city: _city,
        address: _address.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = tr('تعذر حفظ بياناتك. تحقق من الاتصال وحاول مرة أخرى.', "Couldn't save your details. Check the connection and try again.");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('إكمال بيانات الحجز', 'Complete booking details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('بياناتك لإتمام الحجز', 'Your details to complete the booking'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  tr('أكمل البيانات مرة واحدة، وستبقى محفوظة لحجوزاتك القادمة.', 'Fill in your details once, and they stay saved for your next bookings.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                InfoRow(
                  icon: Icons.phone_rounded,
                  label: tr('رقم الهاتف', 'Phone number'),
                  value: user?.phone,
                ),
                const SizedBox(height: 14),
                FieldLabel(tr('الاسم الكامل', 'Full name'), required_: true),
                RaisedField(
                  controller: _name,
                  hint: tr('مثال: أحمد سعد', 'Example: Ahmed Saad'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value.trim().length < 3 ? tr('أدخل الاسم الكامل', 'Enter your full name') : null,
                ),
                const SizedBox(height: 14),
                FieldLabel(tr('المحافظة', 'Province'), required_: true),
                RaisedPicker(
                  value: _city == null ? null : cityLabel(_city!),
                  hint: tr('اختر المحافظة', 'Choose the province'),
                  emptyError: tr('اختر محافظتك', 'Choose your province'),
                  open: _pickingCity,
                  onTap: _pickCity,
                ),
                const SizedBox(height: 14),
                FieldLabel(tr('العنوان التفصيلي', 'Detailed address'), required_: true),
                RaisedField(
                  controller: _address,
                  hint: tr('المنطقة، الشارع، أقرب نقطة دالة', 'Area, street, nearest landmark'),
                  maxLines: 2,
                  validator: (value) => value.trim().length < 8
                      ? tr('أدخل عنواناً تفصيلياً لا يقل عن 8 أحرف', 'Enter a detailed address of at least 8 characters')
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: tr('حفظ ومتابعة الحجز', 'Save and continue booking'),
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
