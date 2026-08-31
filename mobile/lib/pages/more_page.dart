import 'package:flutter/material.dart';
import 'package:future_world_corn_mobile/pages/create_market_page.dart';
import 'package:future_world_corn_mobile/pages/delegate_page.dart';
import 'package:future_world_corn_mobile/pages/humanhouse_page.dart';
import 'package:future_world_corn_mobile/pages/settings_page.dart';
import 'package:future_world_corn_mobile/theme/app_theme.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EntryCard(
            icon: Icons.swap_horiz,
            iconColor: AppTheme.primary,
            title: '委托管理',
            subtitle: 'CORN ↔ govCORN 存取与投票权委托',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DelegatePage())),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.gavel,
            iconColor: AppTheme.no,
            title: 'HumanHouse 争议',
            subtitle: '查看与发起市场争议、参与投票',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HumanHousePage())),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.add_circle_outline,
            iconColor: AppTheme.primary,
            title: '创建市场',
            subtitle: 'Owner 或 marketCreator 地址可创建预测市场',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateMarketPage())),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.settings,
            iconColor: AppTheme.muted,
            title: '网络设置',
            subtitle: 'RPC 节点与钱包地址配置',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EntryCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withAlpha(25),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
        onTap: onTap,
      ),
    );
  }
}
