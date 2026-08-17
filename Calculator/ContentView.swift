import SwiftUI
import CalculatorEngine
import Foundation

// MARK: - Muted / earthy palette (mirrors the reference macOS app)

// Internal (not private) so AboutView and any other view in the module can share
// the same palette as the single source of truth.
extension Color {
    static let bg       = Color(red: 0.095, green: 0.115, blue: 0.110) // deep green-slate
    static let opBg     = Color(red: 0.337, green: 0.475, blue: 0.427) // sage #56796d
    static let numBg    = Color(red: 0.180, green: 0.322, blue: 0.380) // slate-teal #2e5261
    static let topBg    = Color(red: 0.694, green: 0.655, blue: 0.741) // lavender #b1a7bd
    static let warmInk  = Color(red: 0.957, green: 0.933, blue: 0.902) // warm off-white
    static let darkInk  = Color(red: 0.130, green: 0.180, blue: 0.170) // deep green-black
    static let mutedInk = Color(red: 0.694, green: 0.655, blue: 0.741) // muted lavender
}

// MARK: - Button model

/// A calculator button and its styling. `key` is forwarded to the engine.
struct CalcButton: Identifiable {
    enum Style { case op, top, num, percent }

    var id: String { label }
    var label: String
    var key: CalculatorKey
    var style: Style
}

// MARK: - Layout

/// The 5×4 button grid, matching the reference layout.
private let buttonRows: [[CalcButton]] = [
    [CalcButton(label: "AC", key: .clear,        style: .top),
      CalcButton(label: "⌫",  key: .backspace,    style: .top),
      CalcButton(label: "%",  key: .percent,      style: .percent),
     CalcButton(label: "÷",  key: .op(.divide),  style: .op)],
    [CalcButton(label: "7",  key: .digit(7),     style: .num),
     CalcButton(label: "8",  key: .digit(8),     style: .num),
     CalcButton(label: "9",  key: .digit(9),     style: .num),
     CalcButton(label: "×",  key: .op(.multiply),style: .op)],
    [CalcButton(label: "4",  key: .digit(4),     style: .num),
     CalcButton(label: "5",  key: .digit(5),     style: .num),
     CalcButton(label: "6",  key: .digit(6),     style: .num),
     CalcButton(label: "−",  key: .op(.minus),   style: .op)],
    [CalcButton(label: "1",  key: .digit(1),     style: .num),
     CalcButton(label: "2",  key: .digit(2),     style: .num),
     CalcButton(label: "3",  key: .digit(3),     style: .num),
     CalcButton(label: "+",  key: .op(.plus),    style: .op)],
    [CalcButton(label: "0",  key: .digit(0),     style: .num),
     CalcButton(label: ".",  key: .decimal,      style: .num),
      CalcButton(label: "⁺⁄₋",  key: .negate,      style: .num),
     CalcButton(label: "=",  key: .equals,       style: .op)],
]
/// Landscape layout: 5 wide × 4 tall. The number pad (7–9 / 4–6 / 1–3 / 0 . ⁺⁄₋)
/// sits on the left as a classic 3×4 block; the four operators stack in the
/// fourth column and AC / ⌫ / % / = fill the fifth column.
private let landscapeRows: [[CalcButton]] = [
     [CalcButton(label: "7",  key: .digit(7),      style: .num),
      CalcButton(label: "8",  key: .digit(8),      style: .num),
      CalcButton(label: "9",  key: .digit(9),      style: .num),
      CalcButton(label: "÷",  key: .op(.divide),   style: .op),
      CalcButton(label: "AC", key: .clear,         style: .top)],
     [CalcButton(label: "4",  key: .digit(4),      style: .num),
      CalcButton(label: "5",  key: .digit(5),      style: .num),
      CalcButton(label: "6",  key: .digit(6),      style: .num),
      CalcButton(label: "×",  key: .op(.multiply), style: .op),
      CalcButton(label: "⌫",  key: .backspace,     style: .top)],
     [CalcButton(label: "1",  key: .digit(1),      style: .num),
      CalcButton(label: "2",  key: .digit(2),      style: .num),
      CalcButton(label: "3",  key: .digit(3),      style: .num),
      CalcButton(label: "−",  key: .op(.minus),    style: .op),
      CalcButton(label: "%",  key: .percent,       style: .percent)],
     [CalcButton(label: "0",  key: .digit(0),      style: .num),
      CalcButton(label: ".",  key: .decimal,       style: .num),
      CalcButton(label: "⁺⁄₋",  key: .negate,      style: .num),
      CalcButton(label: "+",  key: .op(.plus),     style: .op),
      CalcButton(label: "=",  key: .equals,        style: .op)],
]

struct ContentView: View {
    // `@State` holds a reference to the engine; `display`/`expression` are read
    // directly from it after each press so the UI reflects engine state exactly.
    @State private var calculator = Calculator()
    @State private var display: String = "0"
    @State private var expression: String = ""
    @State private var showAbout = false
    @State private var backspaceTapCount = 0

     // Layout constants (kept here so button size and the grid stay in sync).
     private let gridPadding: CGFloat = 16
     private let gridSpacing: CGFloat = 9
     private let columns = 4

    var body: some View {
        GeometryReader { geo in
            // Rotate the whole layout in landscape: 5 wide × 4 tall, numbers
            // on the left; portrait stays 4 × 5 with square buttons.
            let landscape = geo.size.width > geo.size.height
            let rows = landscape ? landscapeRows : buttonRows
            VStack(spacing: 12) {
                if landscape {
                    displayArea(landscape: true)
                    // Fill the remaining vertical space so the grid sits under
                    // the display and reaches the bottom of the screen.
                    buttonGrid(rows: rows, fillVertically: true, fixedSize: 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    Spacer(minLength: 0)       // push the calculator to the bottom
                    displayArea(landscape: false)
                    buttonGrid(rows: rows,
                               fillVertically: false,
                               fixedSize: buttonSize(for: geo.size.width, columns: columns))
                }
            }
             .padding(gridPadding)
             .background(Color.bg.ignoresSafeArea())
             .fullScreenCover(isPresented: $showAbout) {
                 AboutView()
             }
        }
    }
     // MARK: Key handling

     // Route every press through the engine, then mirror its display/expression
     // back into the UI. Also watches the backspace key: when the display is
     // "0", backspace is a no-op in the engine, so three consecutive taps on an
     // empty display opens the About screen instead of doing nothing.
    private func handlePress(_ key: CalculatorKey) {
        calculator.press(key)
        display = calculator.display
        expression = calculator.expression

        if key == .backspace {
            backspaceTapCount += 1
            if display == "0" && backspaceTapCount >= 3 {
                backspaceTapCount = 0
                showAbout = true
              }
          } else {
            backspaceTapCount = 0
          }
     }
    // Square button edge: fill the available width with N columns and N-1 gaps.
    private func buttonSize(for width: CGFloat, columns: Int) -> CGFloat {
        let available = width - (gridPadding * 2)
        let gaps = CGFloat(columns - 1) * gridSpacing
        return (available - gaps) / CGFloat(columns)
    }

    // MARK: Display (two-line: expression above result)

private func displayArea(landscape: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Expression wraps across lines. Operands and operators are
             // space-separated, so default word wrapping only breaks between
             // them and never splits a number in the middle.
            Text(expression)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.mutedInk.opacity(0.75))

                   .lineLimit(nil)
                   .fixedSize(horizontal: false, vertical: true)
                   .frame(maxWidth: .infinity, alignment: .trailing)
            Text(groupedDisplay)
                   .font(.system(size: landscape ? 56 : 80, weight: .light, design: .rounded)
                          .monospacedDigit())
                 .foregroundColor(.warmInk)
                 .lineLimit(1)
                 .minimumScaleFactor(0.3)
                 .fixedSize(horizontal: false, vertical: true)
                 .frame(maxWidth: .infinity, alignment: .trailing)
         }
         .frame(maxWidth: .infinity, alignment: .trailing)
     }

     // Insert thousand separators into the integer part only, leaving the
     // fractional part and any trailing entry dot (e.g. "12.") untouched.
     private var groupedDisplay: String {
        groupedNumber(display)
      }

     // MARK: Button grid

    private func buttonGrid(rows: [[CalcButton]], fillVertically: Bool,
                            fixedSize: CGFloat) -> some View {
        VStack(spacing: gridSpacing) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: gridSpacing) {
                    ForEach(rows[row]) { button in
                        CalcButtonView(button: button,
                                       width: fixedSize,
                                       fillVertically: fillVertically) {
                            handlePress(button.key)
                         }
                     }
                 }
             }
         }
     }
}

// Insert thousand separators into the integer part of a numeric string.
private func groupedNumber(_ raw: String) -> String {
     guard raw != "Error" else { return raw }
     // Exponential notation (e.g. "1e+09") has no grouping.
     guard !raw.contains("e"), !raw.contains("E") else { return raw }

     var sign = ""
     var s = raw
     if s.hasPrefix("-") {
        sign = "-"
        s.removeFirst()
     }

     let dotIndex = s.firstIndex(of: ".")
     let intPart = dotIndex != nil ? String(s[..<dotIndex!]) : s
     let fracPart = dotIndex != nil ? String(s[s.index(after: dotIndex!)...]) : ""

     var grouped = ""
     for (i, ch) in intPart.enumerated() {
          // Group from the RIGHT so "1000000" -> "1,000,000".
        if i > 0 && (intPart.count - i) % 3 == 0 {
            grouped += ","
         }
        grouped.append(ch)
      }
      var result = sign + grouped
      if dotIndex != nil {
        result += "." + String(fracPart)
      }
     return result
}

/// A rounded, layer-backed style button driven by a tap gesture.
private struct CalcButtonView: View {
    let button: CalcButton
    let width: CGFloat
    let fillVertically: Bool
    let action: () -> Void

      @State private var scale: CGFloat = 1.0

    var body: some View {
        Text(button.label)
              .font(fontFor(button.style))
              .foregroundColor(foregroundFor(button.style))
              .frame(width: fillVertically ? nil : width,
                     height: fillVertically ? nil : width)
              .frame(maxWidth: fillVertically ? .infinity : nil,
                     maxHeight: fillVertically ? .infinity : nil)
            .background(bgFor(button.style))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(scale)
            .onTapGesture {
                scale = 0.94
                action()
                withAnimation(.easeOut(duration: 0.12)) { scale = 1.0 }
            }
    }

    private func fontFor(_ style: CalcButton.Style) -> Font {
        switch style {
        case .op:      return .system(size: 35, weight: .medium)
        case .top:     return .system(size: 32, weight: .medium)
        case .num:     return .system(size: 30, weight: .regular)
        case .percent: return .system(size: 32, weight: .medium)  // 3pt smaller than operators
         }
     }

    private func foregroundFor(_ style: CalcButton.Style) -> Color {
        switch style {
        case .op, .top, .percent: return .darkInk
        case .num:      return .warmInk
        }
    }

    private func bgFor(_ style: CalcButton.Style) -> Color {
        switch style {
        case .op:      return .opBg
        case .top:     return .topBg
        case .num:     return .numBg
        case .percent: return .opBg    // same color scheme as the operators
        }
    }
}

#Preview {
    ContentView()
}
