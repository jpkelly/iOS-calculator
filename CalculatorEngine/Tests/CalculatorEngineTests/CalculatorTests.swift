import XCTest
@testable import CalculatorEngine

final class CalculatorTests: XCTestCase {

    // MARK: Digit entry

    func testDigitEntry() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.digit(2)); c.press(.digit(3))
        XCTAssertEqual(c.display, "123")
    }

    func testLeadingZeroIsReplaced() {
        let c = Calculator()
        c.press(.digit(0)); c.press(.digit(0)); c.press(.digit(5))
        XCTAssertEqual(c.display, "5")
    }

    func testDecimalPoint() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.decimal); c.press(.digit(5))
        XCTAssertEqual(c.display, "1.5")
    }

    func testRepeatedDecimalIgnored() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.decimal); c.press(.decimal)
        c.press(.digit(2)); c.press(.decimal); c.press(.digit(3))
        XCTAssertEqual(c.display, "1.23")
    }

    // MARK: Arithmetic

    func testAddition() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.digit(2)); c.press(.op(.plus)); c.press(.digit(3)); c.press(.equals)
        XCTAssertEqual(c.display, "15")
    }

    func testSubtraction() {
        let c = Calculator()
        c.press(.digit(9)); c.press(.op(.minus)); c.press(.digit(4)); c.press(.equals)
        XCTAssertEqual(c.display, "5")
    }

    func testMultiplication() {
        let c = Calculator()
        c.press(.digit(6)); c.press(.op(.multiply)); c.press(.digit(7)); c.press(.equals)
        XCTAssertEqual(c.display, "42")
    }

    func testDivision() {
        let c = Calculator()
        c.press(.digit(2)); c.press(.digit(0)); c.press(.op(.divide)); c.press(.digit(4)); c.press(.equals)
        XCTAssertEqual(c.display, "5")
    }

    func testDivisionByZeroShowsError() {
        let c = Calculator()
        c.press(.digit(5)); c.press(.op(.divide)); c.press(.digit(0)); c.press(.equals)
        XCTAssertEqual(c.display, "Error")
    }

    func testChainedOperatorsLastWins() {
        // 2 + 3 + 4 = 7 (iOS behavior: pressing + after 3 sets the operand to 3).
        let c = Calculator()
        c.press(.digit(2)); c.press(.op(.plus)); c.press(.digit(3))
        c.press(.op(.plus)); c.press(.digit(4)); c.press(.equals)
        XCTAssertEqual(c.display, "7")
    }

    func testResultContinuesIntoNextOperation() {
        // 2 + 3 = 5, then × 4 = 20
        let c = Calculator()
        c.press(.digit(2)); c.press(.op(.plus)); c.press(.digit(3)); c.press(.equals)
        XCTAssertEqual(c.display, "5")
        c.press(.op(.multiply)); c.press(.digit(4)); c.press(.equals)
        XCTAssertEqual(c.display, "20")
    }

    func testDecimalArithmetic() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.decimal); c.press(.digit(5))
        c.press(.op(.plus))
        c.press(.digit(2)); c.press(.decimal); c.press(.digit(5)); c.press(.equals)
        XCTAssertEqual(c.display, "4")
    }

    func testRepeatingDecimalRoundsToSixSigFigs() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.op(.divide)); c.press(.digit(3)); c.press(.equals)
        XCTAssertEqual(c.display, "0.333333")
    }

    // MARK: Unary actions

    func testNegate() {
        let c = Calculator()
        c.press(.digit(5)); c.press(.negate)
        XCTAssertEqual(c.display, "-5")
    }

    func testNegateWhenFreshIsNoOp() {
        let c = Calculator()
        c.press(.negate)
        XCTAssertEqual(c.display, "0")
    }

    func testPercent() {
        let c = Calculator()
        c.press(.digit(5)); c.press(.digit(0)); c.press(.percent)
        XCTAssertEqual(c.display, "0.5")
    }

    func testBackspace() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.digit(2)); c.press(.digit(3))
        c.press(.backspace)
        XCTAssertEqual(c.display, "12")
    }

    func testBackspaceToZero() {
        let c = Calculator()
        c.press(.digit(7)); c.press(.backspace)
        XCTAssertEqual(c.display, "0")
    }

    // MARK: Clear

    func testClearResetsState() {
        let c = Calculator()
        c.press(.digit(9)); c.press(.op(.plus)); c.press(.digit(9))
        c.press(.clear)
        XCTAssertEqual(c.display, "0")
        XCTAssertEqual(c.expression, "")
        c.press(.digit(4))   // AC should leave a fresh entry
        XCTAssertEqual(c.display, "4")
    }

    // MARK: Expression line

    func testExpressionShownAfterOperator() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.digit(2)); c.press(.op(.plus))
        XCTAssertEqual(c.expression, "12 + ")
    }

    func testExpressionShownAfterEquals() {
        let c = Calculator()
        c.press(.digit(1)); c.press(.digit(2)); c.press(.op(.plus)); c.press(.digit(3)); c.press(.equals)
        XCTAssertEqual(c.display, "15")
         // The full expression (including the last operand) is shown.
        XCTAssertEqual(c.expression, "12 + 3 = ")
      }
      // MARK: Op.apply

       func testOpApply() {
        XCTAssertEqual(Op.plus.apply(2, 3), 5)
        XCTAssertEqual(Op.minus.apply(2, 3), -1)
        XCTAssertEqual(Op.multiply.apply(2, 3), 6)
        XCTAssertEqual(Op.divide.apply(6, 3), 2)
        XCTAssertTrue(Op.divide.apply(5, 0).isNaN)
    }

    // MARK: Edge cases

    func testEqualsWithoutPendingOpIsNoOp() {
        let c = Calculator()
        c.press(.digit(5)); c.press(.equals)
        XCTAssertEqual(c.display, "5")
    }
}
