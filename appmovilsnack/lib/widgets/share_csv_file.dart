// Compartir CSV como archivo (mobile) o como texto (web)

import 'package:share_plus/share_plus.dart';

Future<void> shareCsvAsFile(String csv, String fileName) async {
  await Share.share(csv, subject: fileName);
}
