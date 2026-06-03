import Foundation

/// Protocol for objects that can be destroyed / cleaned up.
public protocol Destroyable: AnyObject {
    func destroy()
}
