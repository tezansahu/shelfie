import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/analytics_provider.dart';

class DomainChart extends ConsumerWidget {
  const DomainChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topDomains = ref.watch(topDomainsProvider);

    if (topDomains.isEmpty) {
      return Card(
        child: Container(
          height: 350, // Reduced to match
          padding: const EdgeInsets.all(16.0),
          child: const Center(
            child: Text('No domain data available'),
          ),
        ),
      );
    }

    return Card(
      child: Container(
        height: 350, // Reduced from 460 to match the new reduced heights
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Domains',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12), // Reduced from 16
            Expanded(
              child: ListView.builder(
                itemCount: topDomains.length > 5 ? 5 : topDomains.length,
                itemBuilder: (context, index) {
                  final domain = topDomains[index];
                  final completionRate = domain.totalCount > 0 
                    ? (domain.completedCount / domain.totalCount)
                    : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                domain.domain,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${domain.completedCount}/${domain.totalCount}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: completionRate,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCompletionColor(completionRate),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(completionRate * 100).toStringAsFixed(1)}% completed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 0.8) return Colors.green;
    if (rate >= 0.6) return Colors.orange;
    if (rate >= 0.4) return Colors.yellow.shade700;
    return Colors.red;
  }
}
