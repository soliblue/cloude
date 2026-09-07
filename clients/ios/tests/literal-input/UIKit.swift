import Foundation

@MainActor public protocol UITextViewDelegate: AnyObject {}
public struct UITextInputTraits: Equatable {
    private let value: Int
    public static let none = UITextInputTraits(value: 0)
    public static let no = UITextInputTraits(value: 1)
    public static let yes = UITextInputTraits(value: 2)
}
public struct UIColor: Equatable {
    public static let clear = UIColor()
    public static let label = UIColor()
}
public struct UIFont {
    public var lineHeight: CGFloat
    public init(lineHeight: CGFloat) { self.lineHeight = lineHeight }
}
public struct UIEdgeInsets { public static let zero = UIEdgeInsets() }
public struct UILayoutPriority { public static let defaultLow = UILayoutPriority() }
public enum NSLayoutConstraint { public enum Axis { case horizontal } }
@MainActor public final class NSTextContainer {
    public var lineFragmentPadding: CGFloat = 5
    public init() {}
}
@MainActor public final class UITextView: NSObject {
    public weak var delegate: (any UITextViewDelegate)?
    public var backgroundColor: UIColor?
    public var textColor: UIColor?
    public var autocapitalizationType = UITextInputTraits.yes
    public var autocorrectionType = UITextInputTraits.yes
    public var spellCheckingType = UITextInputTraits.yes
    public var smartQuotesType = UITextInputTraits.yes
    public var smartDashesType = UITextInputTraits.yes
    public var smartInsertDeleteType = UITextInputTraits.yes
    public var textContainerInset = UIEdgeInsets.zero
    public let textContainer = NSTextContainer()
    public var text = ""
    public var font: UIFont?
    public var tintColor: UIColor?
    public var isEditable = true
    public var accessibilityLabel: String?
    public var selectedRange = NSRange(location: 0, length: 0)
    public var markedTextRange: NSObject?
    public var isFirstResponder = false
    public var isScrollEnabled = true
    public var measuredHeight: CGFloat = 20
    public func setContentCompressionResistancePriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis)
    {}
    @discardableResult public func becomeFirstResponder() -> Bool {
        isFirstResponder = true
        return true
    }
    @discardableResult public func resignFirstResponder() -> Bool {
        isFirstResponder = false
        return true
    }
    public func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: measuredHeight) }
}
