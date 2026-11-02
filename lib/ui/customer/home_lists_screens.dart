import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../auth/push_key.dart';
import '../widgets/ui.dart';
import 'home_keys.dart';

const _listTop = 16.0;
const _listBottom = 24.0;

Color _ground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? homeNightGround : homeCream;

/// كل الأقسام، بشكل أزرارها نفسه في الصفحة الرئيسية.
class AllSectionsScreen extends StatefulWidget {
  const AllSectionsScreen({super.key, this.sections});

  /// ما جلبته الصفحة الرئيسية، فتظهر الصفحة فوراً دون انتظار السيرفر.
  final List<Category>? sections;

  @override
  State<AllSectionsScreen> createState() => _AllSectionsScreenState();
}

class _AllSectionsScreenState extends State<AllSectionsScreen> {
  late final Future<List<Category>>? _sections = widget.sections == null
      ? context.read<AppState>().repo.listCategories().then(customerSections)
      : null;

  @override
  Widget build(BuildContext context) {
    final ground = _ground(context);
    return Scaffold(
      backgroundColor: ground,
      appBar: PushKeyAppBar(title: 'الأقسام', backgroundColor: ground),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final unit = homeUnit(constraints.maxWidth);
          return FutureBuilder<List<Category>>(
            future: _sections,
            initialData: widget.sections,
            builder: (context, snapshot) => ListView(
              padding: EdgeInsets.fromLTRB(0, _listTop * unit, 0, _listBottom * unit),
              children: [
                Center(child: SectionGrid(unit: unit, sections: snapshot.data, placeholders: 18)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// كل الحرفيين المتاحين، بشكل أزرارهم نفسه في الصفحة الرئيسية.
class AllCraftsmenScreen extends StatefulWidget {
  const AllCraftsmenScreen({super.key, this.workers});

  /// ما جلبته الصفحة الرئيسية، فتظهر الصفحة فوراً دون انتظار السيرفر.
  final List<Worker>? workers;

  @override
  State<AllCraftsmenScreen> createState() => _AllCraftsmenScreenState();
}

class _AllCraftsmenScreenState extends State<AllCraftsmenScreen> {
  late final Future<List<Worker>>? _workers = widget.workers == null
      ? context.read<AppState>().repo.listWorkers(onlyAvailable: true)
      : null;

  @override
  Widget build(BuildContext context) {
    final ground = _ground(context);
    return Scaffold(
      backgroundColor: ground,
      appBar: PushKeyAppBar(title: 'حرفي بالقرب منك', backgroundColor: ground),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final unit = homeUnit(constraints.maxWidth);
          return FutureBuilder<List<Worker>>(
            future: _workers,
            initialData: widget.workers,
            builder: (context, snapshot) {
              final workers = snapshot.data;
              if (workers != null && workers.isEmpty) {
                return const EmptyState(
                  icon: Icons.engineering_rounded,
                  title: 'لا يوجد حرفيون متاحون الآن',
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(0, _listTop * unit, 0, _listBottom * unit),
                children: [Center(child: CraftsmanGrid(unit: unit, workers: workers))],
              );
            },
          );
        },
      ),
    );
  }
}
