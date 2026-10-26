import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _demo(String phone, String password) async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    final err = await state.login(phone, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) AppSnack.show(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            right: -120,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: .28),
                  AppColors.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 180,
            left: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: .12),
                  AppColors.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Row(
                    children: [
                      const BrandLogo(size: 46, radius: 14),
                      const SizedBox(width: 10),
                      const BrandTitle(fontSize: 22, color: Colors.white),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        child: const Text('تخطي'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
                        ),
                        child: const Text(
                          'خدمات منزلية · عمال موثوقون · أسعار واضحة',
                          style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'كل خدمة يحتاجها بيتك،\nبضغطة زر واحدة.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 31,
                          height: 1.35,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'احجز كهربائي، مصلح غسالات، صباغ، سباك أو أي عامل محترف.\nادفع بأمان وتابع عملك خطوة بخطوة.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          height: 1.7,
                          color: Color(0xFFA8A8B0),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: const [
                          _Feature(icon: Icons.bolt_rounded, label: 'حجز فوري'),
                          SizedBox(width: 10),
                          _Feature(icon: Icons.verified_user_rounded, label: 'عمال موثوقون'),
                          SizedBox(width: 10),
                          _Feature(icon: Icons.credit_card_rounded, label: 'دفع آمن'),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        PrimaryButton(
                          label: 'إنشاء حساب جديد',
                          icon: Icons.person_add_alt_1_rounded,
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.line),
                            ),
                            child: const Text('لدي حساب بالفعل · تسجيل الدخول'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'تجربة سريعة بدون تسجيل',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _DemoButton(
                                icon: Icons.person_rounded,
                                label: 'زبون تجريبي',
                                busy: _busy,
                                onTap: () => _demo('07701234567', '123456'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DemoButton(
                                icon: Icons.admin_panel_settings_rounded,
                                label: 'حساب المدير',
                                busy: _busy,
                                onTap: () => _demo('07700000000', 'admin123'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.busy,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
