import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../auth/push_key.dart';
import '../widgets/ui.dart';
import 'home_keys.dart';

const _circleSize = 96.0;

/// معلومات الحرفي بعد الضغط على زره في الصفحة الرئيسية.
class CraftsmanInfoScreen extends StatelessWidget {
  const CraftsmanInfoScreen({super.key, required this.worker});

  final Worker worker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final ground = night ? homeNightGround : homeCream;
    final ink = night ? homeNightInk : homeLabel;
    final bio = worker.bio?.trim() ?? '';
    return Scaffold(
      backgroundColor: ground,
      appBar: PushKeyAppBar(title: 'معلومات الحرفي', backgroundColor: ground),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        children: [
          Center(
            child: Container(
              width: _circleSize,
              height: _circleSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 10),
                ],
              ),
              child: Center(
                child: PersonFace(
                  name: worker.name,
                  imagePath: worker.avatarPath,
                  size: _circleSize,
                  color: homeInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            worker.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          Text(
            worker.specialty,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  icon: Icons.star_rounded,
                  value: worker.rating.toStringAsFixed(1),
                  label: 'التقييم',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fact(
                  icon: Icons.task_alt_rounded,
                  value: '${worker.jobsDone}',
                  label: 'عمل منجز',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fact(
                  icon: Icons.event_available_rounded,
                  value: worker.available ? 'متاح' : 'مشغول',
                  label: 'الحالة',
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Text(bio, style: theme.textTheme.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.titleSmall),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
          ),
        ],
      ),
    );
  }
}
