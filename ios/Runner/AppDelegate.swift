import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let CHANNEL = "watermark_app/sharing"
  private var sharedFiles: [String] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    let controller = engineBridge.viewController
    let methodChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    methodChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getSharedFiles":
        result(self?.sharedFiles ?? [])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    
    if url.startAccessingSecurityScopedResource() {
      defer { url.stopAccessingSecurityScopedResource() }
      
      // Copy file to documents directory to ensure access
      let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
      let fileName = url.lastPathComponent
      let destinationURL = documentsPath.appendingPathComponent("shared_\(Date().timeIntervalSince1970)_\(fileName)")
      
      do {
        try FileManager.default.copyItem(at: url, to: destinationURL)
        sharedFiles = [destinationURL.path]
      } catch {
        print("Error copying shared file: \(error)")
      }
    }
    
    return super.application(app, open: url, options: options)
  }
}
