import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../config/firebase_options.dart';

/// Product analytics and push registration.
///
/// ## The rule this class exists to enforce
/// **No health data ever reaches an analytics event.** Not a score, not an
/// answer, not a root cause, not a body measurement. What we log is which
/// screens get used and where people drop out of the funnel - nothing that
/// could describe a named person's sexual health if the analytics account
/// were ever breached or subpoenaed.
///
/// [log] therefore takes only a small closed set of typed events, and there
/// is no free-form parameter map. Adding a new event means adding it here,
/// which forces the question to be asked.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> initialise() async {
    if (!Env.firebaseEnabled) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      _enabled = true;

      // Push is opt-in and only used for training reminders, which are
      // scheduled server-side by the `send-reminders` Edge Function.
      await FirebaseMessaging.instance.requestPermission();
    } on Object catch (error) {
      debugPrint('Analytics unavailable, continuing without it: $error');
      _enabled = false;
    }
  }

  /// The device token used for reminder notifications, or null when push is
  /// unavailable or the user declined.
  Future<String?> pushToken() async {
    if (!_enabled) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      return null;
    }
  }

  Future<void> log(AnalyticsEvent event) async {
    if (!_enabled) return;
    await _analytics?.logEvent(name: event.name);
  }

  Future<void> screen(String name) async {
    if (!_enabled) return;
    await _analytics?.logScreenView(screenName: name);
  }

  /// Honours a user's opt-out. Called from the privacy settings.
  Future<void> setEnabled({required bool value}) async {
    _enabled = value && Env.firebaseEnabled;
    await _analytics?.setAnalyticsCollectionEnabled(_enabled);
  }
}

/// The complete set of events the app may record.
///
/// Every one of these is a *behavioural* signal. None carries a value, a
/// score, an answer or any other health attribute.
enum AnalyticsEvent {
  onboardingStarted,
  onboardingCompleted,
  assessmentStarted,
  assessmentCompleted,
  assessmentAbandoned,
  programViewed,
  sessionLogged,
  exerciseViewed,
  nutritionPlanViewed,
  nutritionPreferencesChanged,
  progressCheckInSubmitted,
  coachQuestionAsked,
  coachAnsweredOffline,
  articleOpened,
  anatomyOpened,
  badgeEarned,
  accountCreated,
  dataDeleted,
}
