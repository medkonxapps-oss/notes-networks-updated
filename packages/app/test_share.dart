import 'package:share_plus/share_plus.dart';

void test() {
  SharePlus.instance.share(ShareParams(
    files: [],
    subject: 'My subject',
    text: 'My text',
  ));
}
