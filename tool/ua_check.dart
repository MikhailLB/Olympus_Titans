// ignore_for_file: avoid_print
import 'package:olympus_titans/core/mobile_http_agent.dart';
void main() async {
  await mobileHttpAgent.prepare();
  final ua = mobileHttpAgent.userAgent;
  print('UA: $ua');
  print('contains appid/: ${ua.contains("appid/")}');
  print('contains appname/: ${ua.contains("appname/")}');
}
