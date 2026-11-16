import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'change_password_screen.dart';
import 'legal_screen.dart';
import 'profile_screen.dart';

/// Read-only account details. University accounts are managed by USEK IT,
/// so nothing here can be edited in the app; only the data the service
/// needs is shown (NFR10).
class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Account details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.brand,
              child: Text(initialsOf(user.name),
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                _Row(icon: Icons.person_outline, label: 'Name', value: user.name),
                const Divider(indent: 56),
                _Row(icon: Icons.mail_outline, label: 'University email', value: user.email),
                const Divider(indent: 56),
                _Row(
                  icon: user.isStaff ? Icons.badge_outlined : Icons.school_outlined,
                  label: 'Account type',
                  value: user.isStaff ? 'Staff' : 'Student',
                ),
                const Divider(indent: 56),
                _Row(icon: Icons.badge_outlined, label: user.universityIdLabel, value: user.universityId),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.password_rounded, color: AppColors.brand),
              title: const Text('Change password',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Use at least 8 characters with letters and numbers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your account is managed by the university. To change your name, email '
                    'or ID, contact the USEK IT department.',
                    style: TextStyle(fontSize: 14.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LegalScreen(document: LegalDocument.privacy),
              )),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Who can see my information?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 16, color: AppColors.ink, fontWeight: FontWeight.w500)),
    );
  }
}
