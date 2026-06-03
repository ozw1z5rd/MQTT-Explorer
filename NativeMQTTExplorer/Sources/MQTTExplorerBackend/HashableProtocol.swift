import Foundation

/// Protocol for objects that produce a unique hash string.
public protocol HashableProtocol {
    func hash() -> String
}
