#include <Cocoa/Cocoa.h>
#include <string.h>

// A clean, self-contained native macOS calculator with a custom dark UI.
// Build:  clang calculator.mm -framework Cocoa -o calculator
// Run:      ./calculator

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static NSString *gDisplay    = nil;   // current number being entered / result
static NSString *gExpression = nil;   // the running expression shown above the display
static NSString *gPendingOp  = nil;    // internal op: "+", "-", "*", "/"
static double    gAccumulator = 0.0;
static bool      gFreshEntry = true;   // next digit starts a fresh number
static NSTextField *gResultLabel   = nil;
static NSTextField *gExprLabel     = nil;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
static void setDisplay(NSString *s) { gDisplay = [s copy]; }
static void setExpression(NSString *s) { gExpression = [s copy]; }

static void refreshDisplay(void) {
    if (gResultLabel) [gResultLabel setStringValue:gDisplay];
    if (gExprLabel)   [gExprLabel setStringValue:gExpression];
}

// Map a display operator symbol to an internal op.
static NSString *internalOp(NSString *title) {
    if ([title isEqualToString:@"+"]) return @"+";
    if ([title isEqualToString:@"−"]) return @"-";   // U+2212 minus sign
    if ([title isEqualToString:@"×"]) return @"*";    // U+00D7 multiply
    if ([title isEqualToString:@"÷"]) return @"/";    // U+00F7 divide
    return nil;
}

// ---------------------------------------------------------------------------
// Button delegate
// ---------------------------------------------------------------------------
@interface CalcDelegate : NSObject
- (void)onButtonClicked:(id)sender;
@end

@implementation CalcDelegate
- (void)onButtonClicked:(id)sender {
    NSString *title = [sender title];

    // --- Clear ---
    if ([title isEqualToString:@"AC"]) {
        setDisplay(@"0");
        setExpression(@"");
        gPendingOp = nil;
        gAccumulator = 0.0;
        gFreshEntry = true;
        refreshDisplay();
        return;
    }

    // --- Backspace ---
    if ([title isEqualToString:@"⌫"]) {                 // U+232B
        NSMutableString *s = [NSMutableString stringWithString:gDisplay];
        if ([s length] > 1 || gFreshEntry) {
            if ([s length] > 0) [s deleteCharactersInRange:NSMakeRange([s length] - 1, 1)];
            if ([s length] == 0) [s appendString:@"0"];
            setDisplay([s copy]);
            gFreshEntry = ([s length] == 1);
        }
        refreshDisplay();
        return;
    }

    // --- Negate ---
    if ([title isEqualToString:@"±"]) {                 // U+00B1
        if (!gFreshEntry) {
            double v = [gDisplay doubleValue] * -1.0;
            setDisplay([NSString stringWithFormat:@"%g", v]);
            refreshDisplay();
        }
        return;
    }

    // --- Percent ---
    if ([title isEqualToString:@"%"]) {
        double v = [gDisplay doubleValue] / 100.0;
        setDisplay([NSString stringWithFormat:@"%g", v]);
        refreshDisplay();
        return;
    }

    // --- Equals ---
    if ([title isEqualToString:@"="]) {
        if (gPendingOp == nil) { refreshDisplay(); return; }
        double a = gAccumulator;
        double b = [gDisplay doubleValue];
        double result = b;
        const char *op = [gPendingOp UTF8String];
        switch (op[0]) {
            case '+': result = a + b; break;
            case '-': result = a - b; break;
            case '*': result = a * b; break;
            case '/': result = (b == 0.0 ? NAN : a / b); break;
        }
        gAccumulator = result;
        setDisplay([NSString stringWithFormat:@"%g", result]);
        setExpression([NSString stringWithFormat:@"%@ = %@", gExpression ?: @"", @""]);
        gPendingOp = nil;
        gFreshEntry = true;
        refreshDisplay();
        return;
    }

    // --- Operators ---
    NSString *op = internalOp(title);
    if (op != nil) {
        if (!gFreshEntry) {
            gAccumulator = [gDisplay doubleValue];
        }
        setExpression([NSString stringWithFormat:@"%@%@ ",
                       (gFreshEntry && [gExpression length] == 0) ?
                           ([NSString stringWithFormat:@"%g", gAccumulator]) : gExpression,
                       title]);
        gPendingOp = op;
        gFreshEntry = true;
        refreshDisplay();
        return;
    }

    // --- Digits and '.' ---
    unichar c = [title characterAtIndex:0];
    if (gFreshEntry) {
        setDisplay(@"0");
        gFreshEntry = false;
    }
    NSMutableString *s = [NSMutableString stringWithString:gDisplay];
    if (c == '.') {
        if ([s rangeOfString:@"."].location == NSNotFound) [s appendString:@"."];
    } else {
        [s appendFormat:@"%c", c];
    }
    setDisplay([s copy]);
    refreshDisplay();
}
@end

// ---------------------------------------------------------------------------
// A rounded, layer-backed button.
// ---------------------------------------------------------------------------
@interface PillButton : NSButton
- (instancetype)initWithFrame:(NSRect)frame
                       title:(NSString *)title
                      target:(id)target
                      action:(SEL)action
                       color:(NSColor *)bg
                        font:(NSFont *)font
                   textColor:(NSColor *)tc;
@end

@implementation PillButton
- (instancetype)initWithFrame:(NSRect)frame
                       title:(NSString *)title
                      target:(id)target
                      action:(SEL)action
                       color:(NSColor *)bg
                        font:(NSFont *)font
                   textColor:(NSColor *)tc {
    self = [super initWithFrame:frame];
    if (self) {
        [self setBordered:NO];
        [self setWantsLayer:YES];
        self.layer.backgroundColor = [bg CGColor];
        self.layer.cornerRadius = 14.0;
        self.title = title;
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: tc,
        };
        self.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
        [self setTarget:target];
        [self setAction:action];
        [self setButtonType:NSButtonTypeMomentaryChange];
    }
    return self;
}

// Never become first responder -> no blue focus ring.
- (BOOL)acceptsFirstResponder { return NO; }
@end

// ---------------------------------------------------------------------------
static void addGrid(NSView *content, NSRect area, CalcDelegate *delegate) {
    // area is the button region (origin bottom-left, height = full grid area).
    struct Cell { const char *title; int row; int col; const char *kind; };
    // kind: "op" (accent), "top" (light gray), "num" (medium gray)
    const Cell cells[] = {
        {"AC", 0, 0, "top"}, {"±", 0, 1, "top"}, {"%", 0, 2, "top"}, {"÷", 0, 3, "op"},
        {"7",  1, 0, "num"}, {"8",  1, 1, "num"}, {"9",  1, 2, "num"}, {"×", 1, 3, "op"},
        {"4",  2, 0, "num"}, {"5",  2, 1, "num"}, {"6",  2, 2, "num"}, {"−", 2, 3, "op"},
        {"1",  3, 0, "num"}, {"2",  3, 1, "num"}, {"3",  3, 2, "num"}, {"+", 3, 3, "op"},
        {"0",  4, 0, "num"}, {".",  4, 1, "num"}, {"=", 4, 2, "op"},  {"⌫", 4, 3, "op"},
    };

    int cols = 4, rows = 5;
    CGFloat pad = 9.0;
    CGFloat cellW = (area.size.width  - pad * (cols - 1)) / cols;
    CGFloat cellH = (area.size.height - pad * (rows - 1)) / rows;

      // Palette inspired by JP's muted / earthy set:
      //   sage #56796d, dusty rose #c5a3a3, slate-teal #2e5261,
      //   dark green #375345, lavender #b1a7bd
    NSColor *accent = [NSColor colorWithRed:0.337 green:0.475 blue:0.427 alpha:1.0]; // sage #56796d
    NSColor *numBg    = [NSColor colorWithRed:0.180 green:0.322 blue:0.380 alpha:1.0]; // slate-teal #2e5261
    NSColor *topBg    = [NSColor colorWithRed:0.694 green:0.655 blue:0.741 alpha:1.0]; // lavender #b1a7bd
    NSColor *white    = [NSColor whiteColor];
    NSColor *darkInk = [NSColor colorWithRed:0.130 green:0.180 blue:0.170 alpha:1.0]; // deep green-black, for light buttons

    for (int i = 0; i < (int)(sizeof(cells) / sizeof(cells[0])); i++) {
        const Cell *cl = &cells[i];
        // y from top -> AppKit bottom-up
        CGFloat topY = area.origin.y + area.size.height - (cl->row + 1) * (cellH + pad);
        CGFloat x    = area.origin.x + cl->col * (cellW + pad);
        NSRect frame = NSMakeRect(x, topY + pad, cellW, cellH);

        NSColor *bg = white;
        NSFont  *font = [NSFont systemFontOfSize:22 weight:NSFontWeightRegular];
        NSColor *tc = white;
        if (strcmp(cl->kind, "op") == 0)      { bg = accent; tc = darkInk; font = [NSFont systemFontOfSize:26 weight:NSFontWeightMedium]; }
        else if (strcmp(cl->kind, "top") == 0) { bg = topBg;  tc = darkInk; font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium]; }
        else { bg = numBg; font = [NSFont systemFontOfSize:24 weight:NSFontWeightRegular]; }

        PillButton *btn = [[PillButton alloc]
            initWithFrame:frame
                  title:[NSString stringWithUTF8String:cl->title]
                 target:delegate
                 action:@selector(onButtonClicked:)
                  color:bg
                   font:font
              textColor:tc];
        [content addSubview:btn];
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        CalcDelegate *delegate = [[CalcDelegate alloc] init];

        gDisplay    = [@"0" copy];
        gExpression = [@" " copy];
        gPendingOp  = [@" " copy];

        int W = 300, H = 440;
        NSScreen *screen = [NSScreen mainScreen];
        NSRect sf = [screen frame];
        int x = (int)(sf.size.width - W) / 2;
        int y = (int)(sf.size.height - H) / 2;

        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(x, y, W, H)
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskFullSizeContentView |
                                 NSWindowStyleMaskClosable |
                                 NSWindowStyleMaskMiniaturizable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [window setTitle:@"Calculator"];
        [window setReleasedWhenClosed:NO];
        [window setOpaque:NO];
        [window setBackgroundColor:[NSColor clearColor]];
        [window setTitleVisibility:NSWindowTitleHidden];
        [window setTitlebarAppearsTransparent:YES];

        NSView *content = [window contentView];
        [content setWantsLayer:YES];
        content.layer.backgroundColor = [NSColor colorWithRed:0.095 green:0.115 blue:0.110 alpha:1.0].CGColor; // deep green-slate
        content.layer.cornerRadius = 16.0;

        // --- Display: two labels (expression + result) at the top ---
        CGFloat displayTop = 78.0;
        CGFloat displayH   = 90.0;
        CGFloat displayY   = H - displayTop - displayH;
        NSRect displayArea = NSMakeRect(20, displayY, W - 40, displayH);

        gExprLabel = [NSTextField labelWithString:@""];
        [gExprLabel setFrame:NSMakeRect(displayArea.origin.x, displayArea.origin.y + displayArea.size.height - 26,
                                        displayArea.size.width, 26)];
        [gExprLabel setFont:[NSFont systemFontOfSize:17 weight:NSFontWeightRegular]];
        [gExprLabel setTextColor:[NSColor colorWithRed:0.694 green:0.655 blue:0.741 alpha:0.75]]; // muted lavender
        [gExprLabel setAlignment:NSTextAlignmentRight];
        [gExprLabel setTag:1002];
        [content addSubview:gExprLabel];

        gResultLabel = [NSTextField labelWithString:@"0"];
        [gResultLabel setFrame:NSMakeRect(displayArea.origin.x, displayArea.origin.y,
                                          displayArea.size.width, 50)];
        [gResultLabel setFont:[NSFont systemFontOfSize:48 weight:NSFontWeightLight]];
        [gResultLabel setTextColor:[NSColor colorWithRed:0.957 green:0.933 blue:0.902 alpha:1.0]]; // warm off-white
        [gResultLabel setAlignment:NSTextAlignmentRight];
        [gResultLabel setTag:1001];
        [content addSubview:gResultLabel];

        refreshDisplay();

        // --- Button grid below the display ---
        CGFloat gridTop = displayY - 12.0;
        NSRect gridArea = NSMakeRect(16, 16, W - 32, gridTop - 16);
        addGrid(content, gridArea, delegate);

        [window makeKeyAndOrderFront:nil];
        [window setInitialFirstResponder:content];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp run];
    }
    return 0;
}
