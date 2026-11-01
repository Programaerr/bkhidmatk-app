import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late String _city;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user!;
    _name = TextEditingController(text: user.name);
    _address = TextEditingController(text: user.address ?? '');
    _city = iraqCities.contains(user.city) ? user.city! : iraqCities.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      await state.updateProfile(state.user!.copyWith(
        name: _name.text.trim(),
        city: _city,
        address: _address.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ الملف الشخصي: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'أكمل بياناتك لمتابعة حجز الخدمة.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'أدخل الاسم الكامل'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: [
                  for (final city in iraqCities)
                    DropdownMenuItem(value: city, child: Text(city)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _city = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'العنوان التفصيلي',
                  hintText: 'المنطقة والشارع وأقرب نقطة دالة',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => (value == null || value.trim().length < 8)
                    ? 'أدخل عنواناً تفصيلياً لا يقل عن 8 أحرف'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'حفظ ومتابعة الحجز',
                onPressed: _save,
                loading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
