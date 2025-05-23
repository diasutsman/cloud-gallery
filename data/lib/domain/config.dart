class ProviderConstants {
  static const String albumFileName = 'Album.json';
  static const String backupFolderName = 'Lock & Key Backup';
  static const String backupFolderPath = '/Lock & Key Backup';
  static const String localRefIdKey = 'local_ref_id';
  static const String dropboxAppTemplateName =
      'Lock & Key Local File Information';
}

class LocalDatabaseConstants {
  static const String databaseName = 'cloud-gallery.db';
  static const String albumDatabaseName = 'cloud-gallery-album.db';
  static const String cleanUpDatabaseName = 'cloud-gallery-clean-up.db';
  static const String uploadQueueTable = 'UploadQueue';
  static const String downloadQueueTable = 'DownloadQueue';
  static const String albumsTable = 'Albums';
  static const String cleanUpTable = 'CleanUp';
}

class FeatureFlag {
  static final googleDriveSupport = true;
}

class ApiConfigs {
  /// The size of the byte to be uploaded from the server in one request.
  static final uploadRequestByteSize = 262144;

  /// The duration to wait before updating the progress of the process.
  static final processProgressUpdateDuration = Duration(milliseconds: 300);
}
