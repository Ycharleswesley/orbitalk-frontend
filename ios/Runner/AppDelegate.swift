import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for screenshot prevention
    let controller = window?.rootViewController as! FlutterViewController
    let screenshotChannel = FlutterMethodChannel(name: "com.orbitalk.screenshot",
                                                 binaryMessenger: controller.binaryMessenger)

    screenshotChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "enableScreenshotPrevention":
        // For iOS, we can try to prevent screenshots by adding a secure text field
        // This is not foolproof but provides some protection
        DispatchQueue.main.async {
          let secureField = UITextField()
          secureField.isSecureTextEntry = true
          controller.view.addSubview(secureField)
          secureField.center = controller.view.center
          secureField.alpha = 0.0
          // Store reference to remove later
          objc_setAssociatedObject(self, "secureField", secureField, .OBJC_ASSOCIATION_RETAIN)
        }
        result(nil)

      case "disableScreenshotPrevention":
        // Remove the secure text field
        DispatchQueue.main.async {
          if let secureField = objc_getAssociatedObject(self, "secureField") as? UITextField {
            secureField.removeFromSuperview()
            objc_setAssociatedObject(self, "secureField", nil, .OBJC_ASSOCIATION_RETAIN)
          }
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
