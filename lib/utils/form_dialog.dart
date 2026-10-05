import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Width of a form dialog's content: all of a phone's width, at most 560 px on wider screens.
double formDialogWidth(BuildContext context) =>
    context.windowSize.isCompact ? double.maxFinite : math.min(560, MediaQuery.sizeOf(context).width * 0.6);

/// Space around a form dialog: small on phones, so the form gets the width.
EdgeInsets formDialogInset(BuildContext context) =>
    context.windowSize.isCompact ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
