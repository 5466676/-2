import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/cleaner_controller.dart';
import '../widgets/full_image_viewer.dart';
import '../widgets/month_picker.dart';
import '../widgets/results_grid.dart';

/// الشاشة الوحيدة — المحتوى بيتغير حسب مرحلة [CleanerController].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CleanerController>();
    final month = c.year != null ? monthLabel(c.year!, c.month!) : null;

    final Widget body = switch (c.stage) {
      Stage.needsPermission => _PermissionView(c),
      Stage.pickMonth => _PickMonthView(c),
      Stage.scanning => _ScanningView(c),
      Stage.results => _ResultsView(c),
      Stage.deleting => const _Busy('عم نمسح الصور…'),
      Stage.done => _DoneView(c),
    };

    final canGoBack = c.stage == Stage.results || c.stage == Stage.done;
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.backToMonths();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            c.stage == Stage.pickMonth || month == null
                ? 'منظّف المعايدات'
                : month,
          ),
          leading: canGoBack
              ? BackButton(onPressed: c.backToMonths)
              : null,
          actions: [
            if (c.stage == Stage.pickMonth) _MemoryMenu(c),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.photo_library_outlined,
      title: 'بدنا صلاحية الصور',
      text: c.error ??
          'التطبيق بيفحص صور الواتساب على جهازك بس — ولا صورة بتطلع برا.',
      actions: [
        FilledButton(
          onPressed: c.requestPermission,
          child: const Text('اسمح بالوصول'),
        ),
        TextButton(
          onPressed: c.openSettings,
          child: const Text('افتح الإعدادات'),
        ),
      ],
    );
  }
}

class _PickMonthView extends StatelessWidget {
  const _PickMonthView(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'اختار الشهر اللي بدك تنظّف معايداته:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (!c.modelAvailable)
          Card(
            margin: const EdgeInsets.all(12),
            color: scheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'ملف المودل مش موجود — التطبيق شغّال بوضع "التعلم من '
                'المحذوفات" بس: بيلاقي الصور الشبيهة بمعايدات مسحتها قبل.',
              ),
            ),
          ),
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(c.error!, style: TextStyle(color: scheme.error)),
          ),
        Expanded(child: MonthPicker(onPicked: c.startScan)),
      ],
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    final s = c.stats;
    final progress = c.total == 0 ? null : s.processed / c.total;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            c.total == 0
                ? 'عم نجيب الصور…'
                : 'عم نفحص ${s.processed} من ${c.total}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 24),
          _StatRow('معايدات لقيناها', s.matched),
          _StatRow('محمية لأن فيها وجوه', s.protectedFaces),
          _StatRow('متجاهلة (اخترت تخليها قبل)', s.skippedKept),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: c.stopScan,
            child: const Text('وقّف واعرض النتائج'),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    final matches = c.matches;
    if (matches.isEmpty) {
      return _Message(
        icon: Icons.check_circle_outline,
        title: 'ما في معايدات',
        text: 'فحصنا ${c.stats.processed} صورة وما لقينا شي يستاهل المسح.'
            '${c.stats.protectedFaces > 0 ? '\n(${c.stats.protectedFaces} صورة محمية لأن فيها وجوه)' : ''}',
        actions: [
          FilledButton(
            onPressed: c.backToMonths,
            child: const Text('اختار شهر تاني'),
          ),
        ],
      );
    }

    final allSelected = c.selectedCount == matches.length;
    return Column(
      children: [
        if (c.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              c.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ListTile(
          title: Text('لقينا ${matches.length} معايدة'),
          subtitle: const Text(
            'شيل الصح عن أي صورة غلط. ضغطة مطوّلة لعرضها كاملة.',
          ),
          trailing: TextButton(
            onPressed: () => c.selectAll(!allSelected),
            child: Text(allSelected ? 'شيل الكل' : 'اختار الكل'),
          ),
        ),
        Expanded(
          child: ResultsGrid(
            matches: matches,
            isSelected: c.isSelected,
            onToggle: c.toggle,
            onOpen: (m) => FullImageViewer.open(
              context,
              candidate: m.candidate,
              isSelected: () => c.isSelected(m.candidate.id),
              onToggle: () => c.toggle(m.candidate.id),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: Text(
                c.selectedCount == 0
                    ? 'احفظ الاختيار بدون مسح'
                    : 'امسح ${c.selectedCount} صورة',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (c.selectedCount == 0) {
      await c.deleteSelected();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: Text(
          'رح تنمسح ${c.selectedCount} صورة. الصور اللي شلت عنها الصح '
          'رح نتذكرها وما نعلّم عليها مرة تانية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('امسح'),
          ),
        ],
      ),
    );
    if (ok == true) await c.deleteSelected();
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    return _Message(
      icon: Icons.cleaning_services_outlined,
      title: c.deletedCount == 0 ? 'انحفظ اختيارك' : 'تمام!',
      text: c.deletedCount == 0
          ? 'ما انمسح شي، بس تعلّمنا من اختيارك.'
          : 'انمسحت ${c.deletedCount} صورة معايدة.',
      actions: [
        FilledButton(
          onPressed: c.backToMonths,
          child: const Text('نظّف شهر تاني'),
        ),
      ],
    );
  }
}

class _MemoryMenu extends StatelessWidget {
  const _MemoryMenu(this.c);

  final CleanerController c;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            'الذاكرة: ${c.rememberedDeleted} محذوفة، '
            '${c.rememberedKept} محتفظ فيها',
          ),
        ),
        PopupMenuItem(
          onTap: () => _confirmClear(context),
          child: const Text('امسح ذاكرة التعلّم'),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح ذاكرة التعلّم؟'),
        content: const Text(
          'التطبيق رح ينسى كل الصور اللي مسحتها أو احتفظت فيها قبل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('امسح'),
          ),
        ],
      ),
    );
    if (ok == true) await c.clearMemory();
  }
}

class _Busy extends StatelessWidget {
  const _Busy(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
