// lib/presentation/features/loyalty/loyalty_transactions_screen.dart
//
// Paginated points ledger. loyalty_rewards_frd.md section 41: server-side
// pagination, never send the whole history to the client in one call.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/loyalty_provider.dart';
import '../../../data/models/loyalty_transaction_model.dart';

class LoyaltyTransactionsScreen extends ConsumerStatefulWidget {
  const LoyaltyTransactionsScreen({super.key});

  @override
  ConsumerState<LoyaltyTransactionsScreen> createState() => _LoyaltyTransactionsScreenState();
}

class _LoyaltyTransactionsScreenState extends ConsumerState<LoyaltyTransactionsScreen> {
  int _page = 1;
  final List<LoyaltyTransaction> _items = [];
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Widget build(BuildContext context) {
    final firstPageAsync = ref.watch(loyaltyTransactionsProvider(1));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: firstPageAsync.when(
        data: (firstPage) {
          if (_items.isEmpty || _page == 1) {
            _items
              ..clear()
              ..addAll(firstPage);
            _hasMore = firstPage.length >= 20;
          }
          if (_items.isEmpty) {
            return Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary)));
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_loadingMore &&
                  _hasMore &&
                  notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                _loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _TransactionTile(tx: _items[i]);
              },
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
      ),
    );
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final more = await ref.read(loyaltyTransactionsProvider(nextPage).future);
    if (!mounted) return;
    setState(() {
      _page = nextPage;
      _items.addAll(more);
      _hasMore = more.length >= 20;
      _loadingMore = false;
    });
  }
}

class _TransactionTile extends StatelessWidget {
  final LoyaltyTransaction tx;
  const _TransactionTile({required this.tx});

  String get _label {
    switch (tx.source) {
      case 'ORDER':
        return tx.metadata['orderNumber']?.toString() ?? 'Order';
      case 'REDEMPTION':
        return tx.metadata['rewardName']?.toString() ?? 'Reward Redemption';
      case 'REFERRAL':
        return 'Referral Bonus';
      case 'REGISTRATION':
        return 'Welcome Bonus';
      case 'BIRTHDAY':
        return 'Birthday Bonus';
      case 'CHALLENGE':
        return tx.metadata['challengeName']?.toString() ?? 'Challenge Reward';
      case 'ADMIN':
        return 'Support Adjustment';
      default:
        return tx.source.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isCredit ? AppColors.success : AppColors.error).withOpacity(0.1),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}'
                  '${tx.status == 'PENDING' ? ' · Pending' : ''}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${tx.points}',
            style: TextStyle(color: isCredit ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
