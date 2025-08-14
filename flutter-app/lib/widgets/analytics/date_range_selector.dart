import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/analytics_models.dart';
import '../../providers/analytics_provider.dart';

class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedDateRangeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Time Range:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AnalyticsDateRange>(
                  value: selectedRange,
                  onChanged: (AnalyticsDateRange? newValue) {
                    if (newValue != null) {
                      ref.read(selectedDateRangeProvider.notifier).state = newValue;
                    }
                  },
                  items: AnalyticsDateRange.values.map((range) {
                    return DropdownMenuItem<AnalyticsDateRange>(
                      value: range,
                      child: Text(range.label),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
