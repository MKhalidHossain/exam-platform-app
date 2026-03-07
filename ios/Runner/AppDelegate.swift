import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    setupScreenPrivacyProtection()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupScreenPrivacyProtection() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  @objc private func appWillResignActive() {
    showPrivacyView()
  }

  @objc private func appDidBecomeActive() {
    if !UIScreen.main.isCaptured {
      hidePrivacyView()
    }
  }

  @objc private func screenCaptureStateChanged() {
    if UIScreen.main.isCaptured {
      showPrivacyView()
    } else {
      hidePrivacyView()
    }
  }

  private func showPrivacyView() {
    guard let window = topWindow() else { return }
    if privacyView == nil {
      let blur = UIBlurEffect(style: .regular)
      let effectView = UIVisualEffectView(effect: blur)
      effectView.frame = window.bounds
      effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

      let label = UILabel(frame: .zero)
      label.text = "Screen capture is restricted"
      label.textColor = UIColor.label
      label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      effectView.contentView.addSubview(label)
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor)
      ])

      privacyView = effectView
    }

    if let view = privacyView, view.superview == nil {
      view.frame = window.bounds
      window.addSubview(view)
    }
  }

  private func hidePrivacyView() {
    privacyView?.removeFromSuperview()
  }

  private func topWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })
    }
    return UIApplication.shared.keyWindow
  }
}
