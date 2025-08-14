import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 12.0), // More padding on mobile
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: isMobile ? 24 : 20, // Larger icon on mobile
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 14 : 12, // Larger text on mobile
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2, // Allow 2 lines for title on mobile
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 8), // More spacing on mobile
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: isMobile ? 20 : 18, // Responsive font size
              ),
            ),
            SizedBox(height: isMobile ? 6 : 4), // More spacing on mobile
            Expanded(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: isMobile ? 12 : 11, // Larger text on mobile
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3, // Allow more lines for subtitle on mobile
              ),
            ),
          ],
        ),
      ),
    );
  }
}
