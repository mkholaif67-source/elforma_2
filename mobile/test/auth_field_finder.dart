import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth fields now have external visual labels and accessibility labels,
/// rather than placeholders. Search dialogs still use their existing hints.
Finder authField(String label) => find.byElementPredicate((element) {
      if (element.widget is! TextField) return false;
      bool matches(String? value) =>
          value == label ||
          (const {
                'كلمة المرور': ['ادخل كلمة المرور', 'اكتب كلمة المرور'],
                'الاسم الكامل': ['اكتب اسمك بالكامل'],
                'البريد الإلكتروني': ['name@example.com'],
                'البريد الإلكتروني أو رقم الهاتف': [
                  'ادخل بريدك الإلكتروني أو رقم هاتفك'
                ],
              }[label]
                  ?.contains(value) ??
              false);
      var found = matches((element.widget as TextField).decoration?.hintText);
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is Semantics && matches(widget.properties.label)) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    });
