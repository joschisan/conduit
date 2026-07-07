import 'package:flutter/material.dart';

const smallStyle = TextStyle(fontSize: 12);
const mediumStyle = TextStyle(fontSize: 16);
const largeStyle = TextStyle(fontSize: 20);
const heroStyle = TextStyle(fontSize: 34);

/// The oversized figure on the balance and amount-entry screens, with its unit
/// suffix. Both are wrapped in a scale-down FittedBox at the call site, so short
/// amounts render at this full size and long ones shrink to fit the width.
const amountStyle = TextStyle(fontSize: 44);
const amountUnitStyle = TextStyle(fontSize: 22);

const smallIconSize = 24.0;
const mediumIconSize = 28.0;
const largeIconSize = 40.0;
const heroIconSize = 56.0;

const listTilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

/// The single spinner shared by every loading indicator in the app.
const smallSpinner = SizedBox(
  width: 14,
  height: 14,
  child: CircularProgressIndicator(strokeWidth: 2),
);

/// The single corner radius shared by every rounded corner in the app —
/// components (buttons, cards, chips, QR surfaces) and edge-attached
/// sheets (drawers, notifications), which round only their free corners.
const cornerRadiusValue = Radius.circular(12);
const cornerRadius = BorderRadius.all(cornerRadiusValue);
