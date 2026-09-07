import Foundation

@propertyWrapper public struct Binding<Value> {
    private let get: () -> Value
    private let set: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
}
@MainActor public protocol UIViewRepresentable {
    associatedtype Coordinator
    func makeCoordinator() -> Coordinator
    typealias Context = UIViewRepresentableContext<Self>
}
@MainActor public struct UIViewRepresentableContext<Value: UIViewRepresentable> {
    public let coordinator: Value.Coordinator
    public init(coordinator: Value.Coordinator) { self.coordinator = coordinator }
}
public struct ProposedViewSize {
    public var width: CGFloat?
    public init(width: CGFloat?) { self.width = width }
}
