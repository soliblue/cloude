import Foundation

struct ExpressionParser {
    private let expression: String
    private var pos: String.Index
    private var variables: [String: Double]

    init(_ expression: String, variables: [String: Double] = [:]) {
        self.expression = expression
        self.pos = expression.startIndex
        self.variables = variables
    }

    static func evaluate(_ expression: String, variables: [String: Double] = [:]) -> Double? {
        var parser = ExpressionParser(expression, variables: variables)
        let result = parser.parseExpression()
        return result.isNaN || result.isInfinite ? nil : result
    }

    static func evaluateOrZero(_ expression: String, variables: [String: Double] = [:]) -> Double {
        evaluate(expression, variables: variables) ?? 0
    }

    private var current: Character? {
        pos < expression.endIndex ? expression[pos] : nil
    }

    private mutating func advance() {
        if pos < expression.endIndex { pos = expression.index(after: pos) }
    }

    private mutating func skipWhitespace() {
        while let c = current, c.isWhitespace { advance() }
    }

    private mutating func parseExpression() -> Double {
        var result = parseTerm()
        while current != nil {
            skipWhitespace()
            if current == "+" { advance(); result += parseTerm() }
            else if current == "-" { advance(); result -= parseTerm() }
            else { break }
        }
        return result
    }

    private mutating func parseTerm() -> Double {
        var result = parsePower()
        while true {
            skipWhitespace()
            if current == "*" { advance(); result *= parsePower() }
            else if current == "/" { advance(); let d = parsePower(); result = d != 0 ? result / d : .nan }
            else { break }
        }
        return result
    }

    private mutating func parsePower() -> Double {
        let base = parseUnary()
        skipWhitespace()
        if current == "^" { advance(); return pow(base, parsePower()) }
        return base
    }

    private mutating func parseUnary() -> Double {
        skipWhitespace()
        if current == "-" { advance(); return -parseUnary() }
        if current == "+" { advance(); return parseUnary() }
        return parseAtom()
    }

    private mutating func parseAtom() -> Double {
        skipWhitespace()

        if current == "(" {
            advance()
            let result = parseExpression()
            skipWhitespace()
            if current == ")" { advance() }
            return result
        }

        if let c = current, c.isLetter {
            var name = ""
            while let c = current, c.isLetter || c == "_" { name.append(c); advance() }

            if current == "(" {
                advance()
                let arg = parseExpression()
                skipWhitespace()
                if current == ")" { advance() }
                return applyFunction(name, arg)
            }

            switch name {
            case "pi": return .pi
            case "e": return M_E
            default: return variables[name] ?? 0
            }
        }

        var numStr = ""
        while let c = current, c.isNumber || c == "." { numStr.append(c); advance() }
        return Double(numStr) ?? 0
    }

    private func applyFunction(_ name: String, _ arg: Double) -> Double {
        switch name {
        case "sin": return sin(arg)
        case "cos": return cos(arg)
        case "tan": return tan(arg)
        case "abs": return abs(arg)
        case "sqrt": return sqrt(arg)
        case "exp": return exp(arg)
        case "log", "ln": return log(arg)
        case "log2": return log2(arg)
        case "log10": return log10(arg)
        case "floor": return floor(arg)
        case "ceil": return ceil(arg)
        case "round": return (arg).rounded()
        case "asin": return asin(arg)
        case "acos": return acos(arg)
        case "atan": return atan(arg)
        default: return 0
        }
    }
}
