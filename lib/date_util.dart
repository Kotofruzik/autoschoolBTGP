import 'package:parse_server_sdk/parse_server_sdk.dart';

String registrationDate(ParseUser user) {
  final date = user.createdAt;
  if (date == null) return 'неизвестно';
  return '${date.day}.${date.month}.${date.year}';
}