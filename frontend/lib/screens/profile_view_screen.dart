import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';

class ProfileViewScreen extends StatelessWidget {
  final bool embedded;
  const ProfileViewScreen({super.key, this.embedded = false});

  Future<void> _editName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Full name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await context.read<AuthProvider>().updateProfile(name: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: AppColors.greenPrimary, size: 40),
              ),
              const SizedBox(height: 14),
              Text(profile?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(profile?.email ?? '', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _tile(
          icon: Icons.cake_outlined,
          title: 'Age',
          value: '${profile?.age ?? "-"} (${profile?.ageGroup ?? ""})',
        ),
        _tile(icon: Icons.edit_outlined, title: 'Edit name', value: '', onTap: () => _editName(context, profile?.name ?? '')),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded, color: AppColors.red),
          label: const Text('Sign out', style: TextStyle(color: AppColors.red)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.redLight),
          ),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
      ],
    );

    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: body);
  }

  Widget _tile({required IconData icon, required String title, required String value, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.greenPrimary),
        title: Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
        trailing: value.isNotEmpty
            ? Text(value, style: const TextStyle(color: AppColors.muted))
            : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }
}
