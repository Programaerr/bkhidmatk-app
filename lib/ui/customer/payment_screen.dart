import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';

class CardResult {
  const CardResult({required this.brand, required this.last4, required this.holder});

  final String brand;
  final String last4;
  final String holder;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.amount});

  final double amount;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _save = true;
  bool _loading = false;
  List<PaymentCard> _saved = const [];
  PaymentCard? _selectedSaved;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final user = context.read<AppState>().user;
    if (user?.id == null) return;
    final cards = await context.read<AppState>().repo.cardsForUser(user!.id!);
    if (mounted) setState(() => _saved = cards);
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_selectedSaved != null) {
      Navigator.pop(
        context,
        CardResult(
          brand: _selectedSaved!.brand,
          last4: _selectedSaved!.last4,
          holder: _selectedSaved!.holder,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    final brand = cardBrand(digits);
    final last4 = digits.substring(digits.length - 4);
    final user = context.read<AppState>().user;
    if (_save && user?.id != null) {
      await context.read<AppState>().repo.addCard(PaymentCard(
            userId: user!.id!,
            brand: brand,
            last4: last4,
            holder: _holder.text.trim(),
            expiry: _expiry.text,
            isDefault: _saved.isEmpty,
          ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context, CardResult(brand: brand, last4: last4, holder: _holder.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberText = _number.text.replaceAll(RegExp(r'\D'), '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدفع بماستركارد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF141417), Color(0xFF2A2606)],
                  ),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -20,
                      bottom: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: .08),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.contactless_rounded, color: AppColors.gold, size: 24),
                            const Spacer(),
                            Text(
                              numberText.isEmpty ? 'Mastercard' : cardBrand(numberText),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _formatDisplay(_number.text),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('حامل البطاقة',
                                      style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _holder.text.isEmpty ? 'CARD HOLDER' : _holder.text.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الانتهاء',
                                    style: TextStyle(color: Colors.white38, fontSize: 8.5)),
                                const SizedBox(height: 2),
                                Text(
                                  _expiry.text.isEmpty ? 'MM/YY' : _expiry.text,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_saved.isNotEmpty) ...[
                const SectionHeader(title: 'بطاقاتك المحفوظة'),
                Column(
                  children: [
                    for (final card in _saved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          borderColor: _selectedSaved?.id == card.id ? AppColors.gold : null,
                          onTap: () => setState(() {
                            _selectedSaved = _selectedSaved?.id == card.id ? null : card;
                          }),
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card_rounded, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${card.brand} ${maskCard(card.last4)}',
                                        style: const TextStyle(
                                            fontSize: 12.5, fontWeight: FontWeight.w800)),
                                    Text('${card.holder} · ${card.expiry}',
                                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                              Icon(
                                _selectedSaved?.id == card.id
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 19,
                                color: _selectedSaved?.id == card.id
                                    ? AppColors.success
                                    : theme.colorScheme.onSurface.withValues(alpha: .3),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('أو أضف بطاقة جديدة', style: theme.textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_selectedSaved == null) ...[
                const FieldLabel('رقم البطاقة', required_: true),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    _CardFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '5555 5555 5555 4444',
                    prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.replaceAll(RegExp(r'\D'), '').length < 16) {
                      return 'أدخل رقماً صحيحاً للبطاقة';
                    }
                    if (!luhnValid(v)) return 'رقم البطاقة غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const FieldLabel('اسم حامل البطاقة', required_: true),
                TextFormField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'AHMED SAAD',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'أدخل اسم حامل البطاقة' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('تاريخ الانتهاء', required_: true),
                          TextFormField(
                            controller: _expiry,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            inputFormatters: [_ExpiryFormatter()],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(hintText: 'MM/YY'),
                            validator: (v) {
                              if (v == null || v.length != 5) return 'غير صالح';
                              final parts = v.split('/');
                              final m = int.tryParse(parts[0]) ?? 0;
                              final y = int.tryParse(parts[1]) ?? 0;
                              if (m < 1 || m > 12) return 'شهر غير صالح';
                              final now = DateTime.now();
                              if (2000 + y < now.year ||
                                  (2000 + y == now.year && m < now.month)) {
                                return 'منتهية';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('CVV', required_: true),
                          TextFormField(
                            controller: _cvv,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(hintText: '•••'),
                            validator: (v) =>
                                (v == null || v.length < 3) ? 'غير صالح' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _save,
                  onChanged: (v) => setState(() => _save = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('حفظ البطاقة للمرات القادمة',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  subtitle: const Text('نحفظ آخر 4 أرقام فقط، ولا نخزن الرقم الكامل.',
                      style: TextStyle(fontSize: 10.5)),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.info.withValues(alpha: .2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppColors.info),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'وضع تجريبي: لا يتم تنفيذ أي خصم حقيقي. استخدم الرقم 5555 5555 5555 4444 للتجربة.',
                        style: TextStyle(fontSize: 10.5, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SoftCard(
                child: Row(
                  children: [
                    Text('المبلغ المستحق', style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(fmtMoney(widget.amount),
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: PrimaryButton(
            label: _selectedSaved != null ? 'استخدام البطاقة المحفوظة' : 'ادفع ${fmtMoney(widget.amount)}',
            icon: Icons.lock_outline_rounded,
            loading: _loading,
            onPressed: _pay,
          ),
        ),
      ),
    );
  }

  String _formatDisplay(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '•••• •••• •••• ••••';
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(i < digits.length ? digits[i] : '•');
    }
    return buffer.toString();
  }
}

class _CardFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    var text = digits;
    if (digits.length >= 3) {
      text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
