import 'dart:convert';
import 'package:crypto/crypto.dart';

String schoolLoginDigest(String login) => sha256
    .convert(
      utf8.encode('gbou-login-directory-v1:${login.trim().toLowerCase()}'),
    )
    .toString();
