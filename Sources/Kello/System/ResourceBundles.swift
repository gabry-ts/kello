import Foundation
import ObjectiveC

/// SwiftPM's generated `Bundle.module` looks for a package's resource bundle at the root
/// of the app, next to Contents, where codesign allows nothing else. `scripts/build.sh`
/// copies those bundles into Contents/Resources instead, and this sends the lookups there,
/// before any package reads its resources.
enum ResourceBundles {
    private typealias InitWithPath = @convention(c) (Unmanaged<AnyObject>, Selector, NSString) -> Unmanaged<AnyObject>?

    /// The original `-[NSBundle initWithPath:]`. Only ever set once, at launch.
    nonisolated(unsafe) private static var original: InitWithPath?

    static func redirectToResources() {
        guard original == nil, let method = class_getInstanceMethod(Bundle.self, #selector(Bundle.init(path:))) else { return }
        // Unmanaged keeps the init's ownership rules (self consumed, result retained)
        // untouched, since both are handed straight to the original.
        let replacement: InitWithPath = { this, selector, path in
            ResourceBundles.original!(this, selector, ResourceBundles.redirected(path as String) as NSString)
        }
        original = unsafeBitCast(method_setImplementation(method, unsafeBitCast(replacement, to: IMP.self)), to: InitWithPath.self)
    }

    /// A missing `<app>/Name.bundle` becomes `<app>/Contents/Resources/Name.bundle`.
    private static func redirected(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension == "bundle",
              url.deletingLastPathComponent().standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL,
              !FileManager.default.fileExists(atPath: path),
              let resources = Bundle.main.resourceURL?.appendingPathComponent(url.lastPathComponent) else { return path }
        return resources.path
    }
}
