import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/history_card.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'profile_view_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
    });
  }

  /// Single entry point into the scan flow. Food and Drinks are now one
  /// combined category, so this always opens the scanner with the
  /// 'food' category (the backend's nutrition-analyzer default) -
  /// no functionality is lost, just the extra choice screen.
  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen(initialCategory: 'food')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeBody(context),
      const HistoryScreen(embedded: true),
      const ProfileViewScreen(embedded: true),
    ];

    Widget body;
    switch (_navIndex) {
      case 1:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _navIndex = 0);
          _openScan();
        });
        body = pages[0];
        break;
      case 2:
        body = pages[1];
        break;
      case 3:
        body = pages[2];
        break;
      default:
        body = pages[0];
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onChanged: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final history = context.watch<HistoryProvider>();
    final name = auth.profile?.name.split(' ').first ?? '';

    return RefreshIndicator(
      onRefresh: () => context.read<HistoryProvider>().load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hi there,', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  Text(name.isEmpty ? 'Welcome' : name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: AppColors.greenPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Single merged "Food & Drinks" entry point - replaces the old
          // separate "Scan a product" hero card plus Food/Drink tiles.
          InkWell(
            onTap: _openScan,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.greenPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Food & Drinks',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan a barcode or enter it manually to get instant guidance',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 32),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent scans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
              TextButton(
                onPressed: () => setState(() => _navIndex = 2),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.items.isEmpty)
            _emptyState()
          else
            ...history.items.take(5).map((item) => HistoryCard(
                  item: item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ResultScreenFromHistory(item: item)),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: AppColors.muted, size: 32),
          SizedBox(height: 10),
          Text('No scans yet', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
          SizedBox(height: 4),
          Text('Scan a barcode or label to get started',
              style: TextStyle(color: AppColors.muted, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}