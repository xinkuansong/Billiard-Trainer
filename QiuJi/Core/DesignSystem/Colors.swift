import SwiftUI

// MARK: - Color tokens（用于 Color(...) 调用场景）

extension Color {
    static let btPrimary        = Color("btPrimary")
    static let btPrimaryMuted   = Color("btPrimaryMuted")
    static let btAccent         = Color("btAccent")
    static let btSuccess        = Color("btSuccess")
    static let btWarning        = Color("btWarning")
    static let btDestructive    = Color("btDestructive")
    static let btBG             = Color("btBG")
    static let btBGSecondary    = Color("btBGSecondary")
    static let btBGTertiary     = Color("btBGTertiary")
    static let btBGQuaternary   = Color("btBGQuaternary")
    static let btText           = Color("btText")
    static let btTextSecondary  = Color("btTextSecondary")
    static let btTextTertiary   = Color("btTextTertiary")
    static let btSeparator      = Color("btSeparator")
    static let btTableFelt      = Color("btTableFelt")
    static let btTableCushion   = Color("btTableCushion")
    static let btTablePocket    = Color("btTablePocket")
    static let btBallCue        = Color("btBallCue")
    static let btBallTarget     = Color("btBallTarget")
    static let btPathCue        = Color("btPathCue")
    static let btPathTarget     = Color("btPathTarget")
}

// MARK: - ShapeStyle extensions（使 .btXxx 在 foregroundStyle / background 上下文中可用）

extension ShapeStyle where Self == Color {
    static var btPrimary:       Color { Color("btPrimary") }
    static var btPrimaryMuted:  Color { Color("btPrimaryMuted") }
    static var btAccent:        Color { Color("btAccent") }
    static var btSuccess:       Color { Color("btSuccess") }
    static var btWarning:       Color { Color("btWarning") }
    static var btDestructive:   Color { Color("btDestructive") }
    static var btBG:            Color { Color("btBG") }
    static var btBGSecondary:   Color { Color("btBGSecondary") }
    static var btBGTertiary:    Color { Color("btBGTertiary") }
    static var btBGQuaternary:  Color { Color("btBGQuaternary") }
    static var btText:          Color { Color("btText") }
    static var btTextSecondary: Color { Color("btTextSecondary") }
    static var btTextTertiary:  Color { Color("btTextTertiary") }
    static var btSeparator:     Color { Color("btSeparator") }
    static var btTableFelt:     Color { Color("btTableFelt") }
    static var btTableCushion:  Color { Color("btTableCushion") }
    static var btTablePocket:   Color { Color("btTablePocket") }
    static var btBallCue:       Color { Color("btBallCue") }
    static var btBallTarget:    Color { Color("btBallTarget") }
    static var btPathCue:       Color { Color("btPathCue") }
    static var btPathTarget:    Color { Color("btPathTarget") }
}
