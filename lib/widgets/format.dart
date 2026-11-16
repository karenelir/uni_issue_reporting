import 'package:intl/intl.dart';

import '../models/issue.dart';

/// "just now", "5 min ago", "3 days ago", or a date for older items.
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM yyyy').format(time);
}

final dateTimeFormat = DateFormat('d MMM yyyy, HH:mm');

/// Short reference shown to the reporter, like a ticket number in 311 apps.
String referenceOf(Issue issue) =>
    'CF-${issue.id.replaceAll(RegExp('[^a-zA-Z0-9]'), '').padRight(6, '0').substring(0, 6).toUpperCase()}';

String plural(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
