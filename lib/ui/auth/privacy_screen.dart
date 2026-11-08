import 'package:flutter/material.dart';

import '../../core/language.dart';
import 'push_key.dart';

/// صفحة سياسة الخصوصية، ويوضع نصها هنا حين يكون جاهزاً.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PushKeyAppBar(title: tr('سياسة و الخصوصية', 'Privacy Policy')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              tr('سيُضاف نص سياسة الخصوصية هنا قريباً.', 'The privacy policy text will be added here soon.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
