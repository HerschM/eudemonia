/// The product's one timestamp format for thoughts and notes: `DD/MM  HH:MM AM/PM`
/// (day first, two-digit 12-hour clock), e.g. `26/11  02:37 PM`.
String formatThoughtTimestamp(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
  final hourStr = hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month  $hourStr:$minute $period';
}
