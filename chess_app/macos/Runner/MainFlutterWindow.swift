import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    let phoneFrame = NSRect(x: 200, y: 100, width: 390, height: 844)
    self.setFrame(phoneFrame, display: true)
    self.minSize = NSSize(width: 320, height: 600)
    self.maxSize = NSSize(width: 430, height: 932)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
