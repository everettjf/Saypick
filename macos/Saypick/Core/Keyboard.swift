//
//  Keyboard.swift
//  Saypick
//
//  合成键盘事件（⌘C/⌘V/⌘A 等）。
//

import CoreGraphics

enum Keyboard {
    static let aKey: CGKeyCode = 0
    static let cKey: CGKeyCode = 8
    static let vKey: CGKeyCode = 9

    /// 发送一次按键，可带 ⌘ 修饰。
    static func press(_ keyCode: CGKeyCode, command: Bool = false) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        if command {
            down.flags = .maskCommand
            up.flags = .maskCommand
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
