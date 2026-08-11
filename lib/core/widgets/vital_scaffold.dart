import 'package:flutter/material.dart';

import '../constants/disclaimers.dart';
import 'disclaimer.dart';

/// The only scaffold the app uses.
///
/// Wrapping `Scaffold` here is what makes the "every screen shows the
/// disclaimer" requirement structural rather than a rule someone has to
/// remember. A screen cannot ship without the footer unless it deliberately
/// reaches past this widget, and a test asserts that none of them do.
class VitalScaffold extends StatelessWidget {
  const VitalScaffold({
    required this.body,
    super.key,
    this.title,
    this.appBar,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padBody = true,
    this.disclaimer,
  });

  final Widget body;
  final String? title;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Set false for screens that manage their own scroll padding (lists).
  final bool padBody;

  /// Overrides the footer text where a screen has a more specific caveat.
  final String? disclaimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          appBar ??
          (title == null
              ? null
              : AppBar(title: Text(title!), actions: actions)),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: appBar == null && title == null,
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: padBody
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: body,
                    )
                  : body,
            ),
            ?bottomNavigationBar,
            DisclaimerFooter(text: disclaimer ?? Disclaimers.standard),
          ],
        ),
      ),
    );
  }
}
