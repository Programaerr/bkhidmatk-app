import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
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
      setState(() => _error = 'انتهت الجلسة، سجل الدخول ثم حاول مرة أخرى');
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
          _error = 'تعذر حفظ بياناتك. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('إكمال بيانات الحجز')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بياناتك لإتمام الحجز',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  'أكمل البيانات مرة واحدة، وستبقى محفوظة لحجوزاتك القادمة.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'رقم الهاتف',
                  value: user?.phone,
                ),
                const SizedBox(height: 14),
                const FieldLabel('الاسم الكامل', required_: true),
                RaisedField(
                  controller: _name,
                  hint: 'مثال: أحمد سعد',
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value.trim().length < 3 ? 'أدخل الاسم الكامل' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('المحافظة', required_: true),
                RaisedPicker(
                  value: _city,
                  hint: 'اختر المحافظة',
                  emptyError: 'اختر محافظتك',
                  open: _pickingCity,
                  onTap: _pickCity,
                ),
                const SizedBox(height: 14),
                const FieldLabel('العنوان التفصيلي', required_: true),
                RaisedField(
                  controller: _address,
                  hint: 'المنطقة، الشارع، أقرب نقطة دالة',
                  maxLines: 2,
                  validator: (value) => value.trim().length < 8
                      ? 'أدخل عنواناً تفصيلياً لا يقل عن 8 أحرف'
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
                  label: 'حفظ ومتابعة الحجز',
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
