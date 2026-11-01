import 'package:flutter/material.dart';

import 'push_key.dart';

/// صفحة سياسة الخصوصية، ويوضع نصها هنا حين يكون جاهزاً.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PushKeyAppBar(title: 'سياسة و الخصوصية'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              'سيُضاف نص سياسة الخصوصية هنا قريباً.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
