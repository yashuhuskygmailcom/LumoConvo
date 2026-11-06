class UserPreferences {
  const UserPreferences({
    this.notificationsEnabled = true,
    this.messagePreviews = true,
    this.soundsEnabled = true,
    this.showOnlineStatus = true,
  });

  final bool notificationsEnabled;
  final bool messagePreviews;
  final bool soundsEnabled;
  final bool showOnlineStatus;

  factory UserPreferences.fromMap(Map<String, dynamic>? data) {
    return UserPreferences(
      notificationsEnabled: data?['notificationsEnabled'] as bool? ?? true,
      messagePreviews: data?['messagePreviews'] as bool? ?? true,
      soundsEnabled: data?['soundsEnabled'] as bool? ?? true,
      showOnlineStatus: data?['showOnlineStatus'] as bool? ?? true,
    );
  }

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? messagePreviews,
    bool? soundsEnabled,
    bool? showOnlineStatus,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      messagePreviews: messagePreviews ?? this.messagePreviews,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    );
  }

  Map<String, dynamic> toMap() => {
    'notificationsEnabled': notificationsEnabled,
    'messagePreviews': messagePreviews,
    'soundsEnabled': soundsEnabled,
    'showOnlineStatus': showOnlineStatus,
  };
}
