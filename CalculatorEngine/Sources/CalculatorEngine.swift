import Foundation

// MARK: - Operators

/// Arithmetic operations supported by the calculator.
public enum Op: String, CaseIterable, Sendable {
    case plus     = "+"
    case minus    = "-"
    case multiply = "*"
    case divide   = "/"

    /// The glyph shown to the user (+, −, ×, ÷).
    public var displaySymbol: String {
        switch self {
        case .plus:     return "+"
        case .minus:    return "\u{2212}"     // −
        case .multiply: return "\u{00D7}"     // ×
        case .divide:   return "\u{00F7}"     // ÷
        }
    }

    /// Applies the operation to the two operands. Division by zero returns `.nan`.
    public func apply(_ lhs: Double, _ rhs: Double) -> Double {
        switch self {
        case .plus:     return lhs + rhs
        case .minus:    return lhs - rhs
        case .multiply: return lhs * rhs
        case .divide:   return rhs == 0 ? .nan : lhs / rhs
        }
    }
}

// MARK: - Keys

/// A single button press on the calculator.
public enum CalculatorKey: Hashable, Sendable {
    case clear        // AC
    case backspace    // ⌫
    case negate       // ±
    case percent      // %
    case equals       // =
    case op(Op)
    case digit(Int)
    case decimal
}

// MARK: - Calculator

/// A stateful calculator engine, independent of any UI framework.
///
/// Mirrors the behavior of the original `calculator.mm` (a two-line display:
/// an expression line above a result line), but is a plain Swift type that can
/// be wrapped by SwiftUI, UIKit, or driven directly from tests.
public final class Calculator {

    /// The value currently shown in the main display.
    public private(set) var display: String = "0"

    /// The running expression shown above the display (e.g. "12 + ").
    public private(set) var expression: String = ""

    /// Whether the next digit should start a fresh number.
    public private(set) var isFreshEntry: Bool = true

    private var pendingOp: Op?
    private var accumulator: Double = 0

      /// Set right after "=". Lets an operator pressed immediately after "=" continue
      /// the chain from the result (e.g. "5 + 5 = +" -> "5 + 5 = 10 + ").
    private var justEvaluated: Bool = false

    public init() {}

    // MARK: Public API

    /// Returns the engine to its initial state.
    public func reset() {
        display = "0"
        expression = ""
        pendingOp = nil
        accumulator = 0
        isFreshEntry = true
        justEvaluated = false
    }

    /// Handles a button press and updates the display.
    public func press(_ key: CalculatorKey) {
        switch key {
        case .clear:       reset()
        case .backspace:   backspace()
        case .negate:      negate()
        case .percent:     percent()
        case .equals:      equals()
        case .op(let op):  enterOperator(op)
        case .digit(let d): inputDigit(d)
        case .decimal:     inputDecimal()
        }
    }

    // MARK: Digit / decimal input

    private func inputDigit(_ digit: Int) {
        if isFreshEntry {
            display = String(digit)
            isFreshEntry = false
        } else if display == "0" {
            // Replace a leading zero so "0" + "5" becomes "5", not "05".
            display = String(digit)
        } else {
            display += String(digit)
        }
    }

    private func inputDecimal() {
        if isFreshEntry {
            display = "0."
            isFreshEntry = false
        } else if !display.contains(".") {
            display += "."
        }
    }

    // MARK: Operators

    private func enterOperator(_ op: Op) {
        if !isFreshEntry {
            // Fold the just-typed operand into the running expression.
            let operand = format(currentValue)
            expression = expression.isEmpty ? operand : expression + operand

             // Fold any pending operation before starting the new one, so chained
             // operators accumulate: 2 + 2 + 2 => 6, not 4.
            if let pending = pendingOp {
                accumulator = pending.apply(accumulator, currentValue)
                display = format(accumulator)    // show the intermediate result
             } else {
                accumulator = currentValue
               }
          } else if justEvaluated {
             // Operator right after "=": continue the chain from the result,
             // e.g. "5 + 5 = +" -> "5 + 5 = 10 + ".
            expression = expression.trimmingCharacters(in: .whitespaces) + " " + display
          }
        justEvaluated = false
        expression += " " + op.displaySymbol + " "
        pendingOp = op
        isFreshEntry = true
     }
    private func equals() {
        guard let op = pendingOp else { return }
        // Capture the right operand BEFORE overwriting the display with the result.
        let rightOperand = format(currentValue)
        let result = op.apply(accumulator, currentValue)
        accumulator = result
        display = format(result)
         // Append the final (right) operand and a trailing "=" so the expression reads
         // e.g. "5 × 3 =", with the result shown only on the main display.
        expression = expression.trimmingCharacters(in: .whitespaces)
             + (rightOperand.isEmpty ? "" : " " + rightOperand) + " ="
        pendingOp = nil
        isFreshEntry = true
    }

    private func backspace() {
        guard !display.isEmpty, display != "0" else { return }
        var chars = Array(display)
        chars.removeLast()
        if chars.isEmpty {
            chars = ["0"]
        }
        display = String(chars)
        isFreshEntry = (display.count == 1)
    }

    private func negate() {
        guard !isFreshEntry else { return }
        display = format(-currentValue)
    }

    private func percent() {
        display = format(currentValue / 100.0)
    }

    // MARK: Helpers

    private var currentValue: Double {
        Double(display) ?? 0
    }

    private func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "Error" }
        if value == 0 { return "0" }           // avoid "-0"
        return String(format: "%g", value)
    }
}
