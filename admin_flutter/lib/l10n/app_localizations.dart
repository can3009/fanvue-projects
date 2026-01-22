import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settingsTitle': 'Settings',
      'language': 'Language',
      'session': 'Session',
      'supabaseUrl': 'Supabase URL',
      'user': 'User',
      'notes': 'Notes',
      'notesContent1': 'Use Supabase RLS policies to protect admin data.',
      'notesContent2':
          'Jobs are queued; the worker handles delivery to Fanvue.',
      'dashboard': 'Dashboard',
      'creators': 'Creators',
      'fans': 'Fans',
      'jobs': 'Jobs',
      'dailyUsage': 'Daily Usage',
      'recentConversations': 'Recent Conversations',
      'quickTurnaround': 'Quick Turnaround',
      'activeNow': 'Active Now',
      'totalRevenue': 'Total Revenue',
      'newSubs': 'New Subs',
      'jobsQueue': 'Jobs Queue',
      'recentErrors': 'Recent Job Errors',
      'processQueue': 'Start Processing Queue',
      'processQueueDesc': 'Will process pending jobs for',
      'allCreators': 'ALL creators',
      'pause': 'Pause',
      'processing': 'Processing Queue...',
      'errorLoadingDashboard': 'Error loading dashboard: ',
      'overview': 'Overview',
      'refreshData': 'Refresh Data',
      'queuedJobs': 'Queued Jobs',
      'quickActions': 'Quick Actions',
      'addCreator': 'Add Creator',
      'latestMessages': 'Latest Messages',
      'noMessagesReceived': 'No messages received yet.',
      'msg': 'Msg',
      'recentJobErrors': 'Recent Job Errors',
      'noRecentErrors': 'No recent errors found. Systems maintained.',
      'unknownError': 'Unknown error',
      'filterByCreator': 'Filter by Creator',
      'none': 'None',
      'noCreatorsFound': 'No creators found',
      'startProcessingQueue': 'Start Processing Queue',
      'willProcessJobsFor': 'Will process pending jobs for',
      'noJobsFound': 'No jobs in queue',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'unknown': 'Unknown',
      'errorLabel': 'Error: ',
      'resultLabel': 'Result: ',
      'refreshJobs': 'Refresh Jobs',
      'noCreatorsConfigured': 'No creators configured.',
      'displayName': 'Display Name',
      'systemPrompt': 'System Prompt',
      'defaultPacing': 'Default Pacing (s)',
      'update': 'Update',
      'filterByFan': 'Filter by Fan',
      'noFansFound': 'No fans found',
      'send': 'Send',
      'typeAMessage': 'Type a message...',
      'spend': 'Spend',
      'messages': 'Messages',
      'active': 'Active',
      'inactive': 'Inactive',
      'save': 'Save',
      'create': 'Create',
      'edit': 'Edit',
      'delete': 'Delete',
      'deleteCreatorTitle': 'Delete Creator?',
      'deleteCreatorConfirm':
          'Are you sure you want to delete "%s"?\n\nThis will permanently delete all data.',
      'selectCreatorToManage': 'Select a creator to manage',
      'deleteFanTitle': 'Delete Fan?',
      'deleteFanConfirm':
          'Are you sure you want to delete "%s"?\n\nAll messages and data will be permanently deleted.',
      'selectFanToView': 'Select a fan to view messages',
      'refreshCreators': 'Refresh Creators',
      'refreshMessages': 'Refresh Messages',
      'selectCreator': 'Select Creator',
      'massMessagesTitle': 'Mass Messages',
      'audience': 'Audience',
      'writeMessage': 'Write Message',
      'generateWithGrok': 'Generate with Grok',
      'sendMassMessage': 'Send Mass Message',
      'selectAudience': 'Select Audience',
      'allSubs': 'All Subscribers',
      'highSpenders': 'High Spenders',
      'newSubscribers': 'New Subscribers',
      'inactiveSubs': 'Inactive Subscribers',
      'messageTemplate': 'Message Template',
      'ppvRequestsTitle': 'PPV Requests',
      'manageRequests': 'Manage custom content requests',
      'close': 'Close',
      'accept': 'Accept',
      'decline': 'Decline',
      'massMessagesDesc': 'Send bulk messages to your fans',
      'vips': 'VIPs',
      'selectedLists': 'Selected: %s lists',
      'dailyRevenue': 'Daily Revenue',
    },
    'de': {
      'settingsTitle': 'Einstellungen',
      'language': 'Sprache',
      'session': 'Sitzung',
      'supabaseUrl': 'Supabase URL',
      'user': 'Benutzer',
      'notes': 'Hinweise',
      'notesContent1':
          'Verwenden Sie Supabase RLS-Richtlinien zum Schutz der Admin-Daten.',
      'notesContent2':
          'Jobs werden in die Warteschlange gestellt; der Worker übernimmt die Zustellung an Fanvue.',
      'dashboard': 'Dashboard',
      'creators': 'Creator',
      'fans': 'Fans',
      'jobs': 'Jobs',
      'dailyUsage': 'Tägliche Nutzung',
      'recentConversations': 'Letzte Gespräche',
      'quickTurnaround': 'Schnelle Bearbeitung',
      'activeNow': 'Jetzt aktiv',
      'totalRevenue': 'Gesamtumsatz',
      'newSubs': 'Neue Abos',
      'jobsQueue': 'Job-Warteschlange',
      'recentErrors': 'Letzte Job-Fehler',
      'processQueue': 'Warteschlange verarbeiten',
      'processQueueDesc': 'Verarbeitet ausstehende Jobs für',
      'allCreators': 'ALLE Creator',
      'pause': 'Pause',
      'processing': 'Verarbeite Warteschlange...',
      'errorLoadingDashboard': 'Fehler beim Laden des Dashboards: ',
      'overview': 'Übersicht',
      'refreshData': 'Daten aktualisieren',
      'queuedJobs': 'Wartende Jobs',
      'quickActions': 'Schnellzugriff',
      'addCreator': 'Creator hinzufügen',
      'latestMessages': 'Neueste Nachrichten',
      'noMessagesReceived': 'Noch keine Nachrichten erhalten.',
      'msg': 'Nachricht',
      'recentJobErrors': 'Letzte Job-Fehler',
      'noRecentErrors': 'Keine Fehler gefunden. Systeme laufen.',
      'unknownError': 'Unbekannter Fehler',
      'filterByCreator': 'Nach Creator filtern',
      'none': 'Keine',
      'noCreatorsFound': 'Keine Creator gefunden',
      'startProcessingQueue': 'Verarbeitung starten',
      'willProcessJobsFor': 'Verarbeitet ausstehende Jobs für',
      'noJobsFound': 'Keine Jobs in der Warteschlange',
      'retry': 'Wiederholen',
      'cancel': 'Abbrechen',
      'unknown': 'Unbekannt',
      'errorLabel': 'Fehler: ',
      'resultLabel': 'Ergebnis: ',
      'refreshJobs': 'Jobs aktualisieren',
      'noCreatorsConfigured': 'Keine Creator konfiguriert.',
      'displayName': 'Anzeigename',
      'systemPrompt': 'System-Prompt',
      'defaultPacing': 'Standard-Pacing (s)',
      'update': 'Aktualisieren',
      'filterByFan': 'Nach Fan filtern',
      'noFansFound': 'Keine Fans gefunden',
      'send': 'Senden',
      'typeAMessage': 'Nachricht eingeben...',
      'spend': 'Ausgaben',
      'messages': 'Nachrichten',
      'active': 'Aktiv',
      'inactive': 'Inaktiv',
      'save': 'Speichern',
      'create': 'Erstellen',
      'edit': 'Bearbeiten',
      'delete': 'Löschen',
      'deleteCreatorTitle': 'Creator löschen?',
      'deleteCreatorConfirm':
          'Möchten Sie "%s" wirklich löschen?\n\nDies wird alle Daten dauerhaft löschen.',
      'selectCreatorToManage': 'Wählen Sie einen Creator zum Verwalten',
      'deleteFanTitle': 'Fan löschen?',
      'deleteFanConfirm':
          'Möchten Sie "%s" wirklich löschen?\n\nAlle Nachrichten und Daten werden dauerhaft gelöscht.',
      'selectFanToView': 'Wählen Sie einen Fan zum Anzeigen',
      'refreshCreators': 'Creator aktualisieren',
      'refreshMessages': 'Nachrichten aktualisieren',
      'selectCreator': 'Creator wählen',
      'massMessagesTitle': 'Massen-Nachrichten',
      'audience': 'Zielgruppe',
      'writeMessage': 'Nachricht schreiben',
      'generateWithGrok': 'Mit Grok generieren',
      'sendMassMessage': 'Massen-Nachricht senden',
      'selectAudience': 'Zielgruppe wählen',
      'allSubs': 'Alle Abonnenten',
      'highSpenders': 'Hohe Ausgaben',
      'newSubscribers': 'Neue Abonnenten',
      'inactiveSubs': 'Inaktive Abonnenten',
      'messageTemplate': 'Nachrichtenvorlage',
      'ppvRequestsTitle': 'PPV Anfragen',
      'manageRequests': 'Anfragen verwalten',
      'close': 'Schließen',
      'accept': 'Akzeptieren',
      'decline': 'Ablehnen',
      'massMessagesDesc': 'Massen-Nachrichten an Ihre Fans senden',
      'vips': 'VIPs',
      'selectedLists': 'Ausgewählt: %s Listen',
      'dailyRevenue': 'Tagesumsatz',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Getters for keys (to avoid typos in usage)
  String get settingsTitle => get('settingsTitle');
  String get language => get('language');
  String get session => get('session');
  String get supabaseUrl => get('supabaseUrl');
  String get user => get('user');
  String get notes => get('notes');
  String get notesContent1 => get('notesContent1');
  String get notesContent2 => get('notesContent2');
  String get dashboard => get('dashboard');
  String get creators => get('creators');
  String get fans => get('fans');
  String get jobs => get('jobs');
  String get dailyUsage => get('dailyUsage');
  String get recentConversations => get('recentConversations');
  String get quickTurnaround => get('quickTurnaround');
  String get activeNow => get('activeNow');
  String get totalRevenue => get('totalRevenue');
  String get newSubs => get('newSubs');
  String get jobsQueue => get('jobsQueue');
  String get recentErrors => get('recentErrors');
  String get processQueue => get('processQueue');
  String get processQueueDesc => get('processQueueDesc');
  String get allCreators => get('allCreators');
  String get pause => get('pause');
  String get processing => get('processing');
  String get overview => get('overview');
  String get refreshData => get('refreshData');
  String get queuedJobs => get('queuedJobs');
  String get quickActions => get('quickActions');
  String get addCreator => get('addCreator');
  String get latestMessages => get('latestMessages');
  String get noMessagesReceived => get('noMessagesReceived');
  String get msg => get('msg');
  String get recentJobErrors => get('recentJobErrors');
  String get noRecentErrors => get('noRecentErrors');
  String get unknownError => get('unknownError');
  String get filterByCreator => get('filterByCreator');
  String get none => get('none');
  String get noCreatorsFound => get('noCreatorsFound');
  String get startProcessingQueue => get('startProcessingQueue');
  String get willProcessJobsFor => get('willProcessJobsFor');
  String get noJobsFound => get('noJobsFound');
  String get retry => get('retry');
  String get cancel => get('cancel');
  String get unknown => get('unknown');
  String get errorLabel => get('errorLabel');
  String get resultLabel => get('resultLabel');
  String get refreshJobs => get('refreshJobs');
  String get noCreatorsConfigured => get('noCreatorsConfigured');
  String get displayName => get('displayName');
  String get systemPrompt => get('systemPrompt');
  String get defaultPacing => get('defaultPacing');
  String get update => get('update');
  String get filterByFan => get('filterByFan');
  String get noFansFound => get('noFansFound');
  String get send => get('send');
  String get typeAMessage => get('typeAMessage');
  String get spend => get('spend');
  String get messages => get('messages');
  String get active => get('active');
  String get inactive => get('inactive');
  String get save => get('save');
  String get create => get('create');
  String get edit => get('edit');
  String get delete => get('delete');
  String get deleteCreatorTitle => get('deleteCreatorTitle');
  String get selectCreatorToManage => get('selectCreatorToManage');
  String get deleteFanTitle => get('deleteFanTitle');
  String get selectFanToView => get('selectFanToView');
  String get refreshCreators => get('refreshCreators');
  String get refreshMessages => get('refreshMessages');
  String get selectCreator => get('selectCreator');
  String get massMessagesTitle => get('massMessagesTitle');
  String get audience => get('audience');
  String get writeMessage => get('writeMessage');
  String get generateWithGrok => get('generateWithGrok');
  String get sendMassMessage => get('sendMassMessage');
  String get selectAudience => get('selectAudience');
  String get allSubs => get('allSubs');
  String get highSpenders => get('highSpenders');
  String get newSubscribers => get('newSubscribers');
  String get inactiveSubs => get('inactiveSubs');
  String get messageTemplate => get('messageTemplate');
  String get ppvRequestsTitle => get('ppvRequestsTitle');
  String get manageRequests => get('manageRequests');
  String get close => get('close');
  String get accept => get('accept');
  String get decline => get('decline');
  String get massMessagesDesc => get('massMessagesDesc');
  String get vips => get('vips');
  String selectedLists(String count) =>
      get('selectedLists').replaceAll('%s', count);
  String get dailyRevenue => get('dailyRevenue');

  String deleteCreatorConfirm(String name) =>
      get('deleteCreatorConfirm').replaceAll('%s', name);
  String deleteFanConfirm(String name) =>
      get('deleteFanConfirm').replaceAll('%s', name);

  // Methods for parameterized strings
  String errorLoadingDashboard(String error) =>
      '${get('errorLoadingDashboard')}$error';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
