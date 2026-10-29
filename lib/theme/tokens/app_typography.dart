import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const _display = 'ClashDisplay';
  static const _body = 'RobotoFlex'; // Expressive variable font
  static const _mono = 'GeistMono';

  static const displayXl = TextStyle(
    fontFamily: _display,
    fontSize: 48,
    height: 1.1,
    fontWeight: FontWeight.w500,
  );
  static const displayLg = TextStyle(
    fontFamily: _display,
    fontSize: 36,
    height: 1.15,
    fontWeight: FontWeight.w500,
  );
  static const displayMd = TextStyle(
    fontFamily: _display,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  static const displaySm = TextStyle(
    fontFamily: _display,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const bodyLg = TextStyle(
    fontFamily: _body,
    fontSize: 16,
    height: 1.5,
  );
  static const bodyMd = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    height: 1.5,
  );
  static const bodySm = TextStyle(
    fontFamily: _body,
    fontSize: 13,
    height: 1.5,
  );
  static const bodyXs = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    height: 1.5,
  );

  static const monoMd = TextStyle(
    fontFamily: _mono,
    fontSize: 14,
    height: 1.5,
  );
}

