import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/history_provider.dart';
import '../widgets/history_card.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  final bool embedded;
  const HistoryScreen({super.key, this.embedded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();

    final body = RefreshIndicator(
      onRefresh: () => context.read<HistoryProvider>().load(),
      child: history.isLoading && history.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : history.items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.inventory_2_outlined, color: AppColors.muted, size: 40),
                    SizedBox(height: 12),
                    Center(
                        child: Text('No scan history yet',
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: history.items.length,
                  itemBuilder: (context, i) {
                    final item = history.items[i];
                    return HistoryCard(
                      item: item,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ResultScreenFromHistory(item: item)),
                      ),
                      onDismiss: () => context.read<HistoryProvider>().delete(item.id),
                    );
                  },
                ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scan History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (history.items.isNotEmpty)
                  TextButton(
                    onPressed: () => context.read<HistoryProvider>().clearAll(),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Scan History')), body: body);
  }
}
