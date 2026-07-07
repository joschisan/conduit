import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDocumentsFromBackup()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The Documents directory holds the wallet database, including the seed
  /// entropy. Recovery is covered by the seed phrase, so keep the database out
  /// of iCloud and device backups rather than letting the seed leave the
  /// device. Runs on every launch since the flag is per-path and idempotent.
  private func excludeDocumentsFromBackup() {
    guard
      var documents = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
      ).first
    else { return }

    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? documents.setResourceValues(values)
  }
}
