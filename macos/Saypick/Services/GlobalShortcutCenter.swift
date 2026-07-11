//
//  GlobalShortcutCenter.swift
//  Saypick
//
//  全局快捷键管理器 - 支持注册多个独立热键（按 id 区分）。
//

import AppKit
import Carbon

struct KeyboardShortcutPreference: Codable, Equatable {
    var keyCode: Int
    var modifiers: ModifierFlags

    struct ModifierFlags: OptionSet, Codable, Equatable {
        let rawValue: UInt

        static let command = ModifierFlags(rawValue: 1 << 0)
        static let option = ModifierFlags(rawValue: 1 << 1)
        static let control = ModifierFlags(rawValue: 1 << 2)
        static let shift = ModifierFlags(rawValue: 1 << 3)

        var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.command) { flags |= UInt32(cmdKey) }
            if contains(.option) { flags |= UInt32(optionKey) }
            if contains(.control) { flags |= UInt32(controlKey) }
            if contains(.shift) { flags |= UInt32(shiftKey) }
            return flags
        }

        var displayString: String {
            var components: [String] = []
            if contains(.control) { components.append("⌃") }
            if contains(.option) { components.append("⌥") }
            if contains(.shift) { components.append("⇧") }
            if contains(.command) { components.append("⌘") }
            return components.joined()
        }
    }

    var displayString: String {
        let keyName = KeyCodeMapper.string(for: keyCode) ?? "Unknown"
        return modifiers.displayString + keyName
    }
}

final class GlobalShortcutCenter {
    static let shared = GlobalShortcutCenter()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// 注册一个热键。同一 id 重复注册会覆盖旧的。
    func register(id: UInt32, shortcut: KeyboardShortcutPreference, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        unregister(id: id)

        handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: "TRNL".fourCharCode, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode),
                                         shortcut.modifiers.carbonFlags,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        if status == noErr, let ref {
            hotKeyRefs[id] = ref
        } else {
            handlers[id] = nil
        }
    }

    func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs[id] = nil
        handlers[id] = nil
    }

    func unregisterAll() {
        for id in Array(hotKeyRefs.keys) { unregister(id: id) }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<GlobalShortcutCenter>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            manager.handlers[hkID.id]?()
            return noErr
        }, 1, &eventSpec, selfPointer, &eventHandler)
    }

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

private extension String {
    var fourCharCode: OSType {
        var result: OSType = 0
        for scalar in unicodeScalars.prefix(4) {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }
}

// 按键代码映射
struct KeyCodeMapper {
    static func string(for keyCode: Int) -> String? {
        let mapping: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space",
            50: "`",
            36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
            96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            118: "F4", 120: "F2", 122: "F1"
        ]
        return mapping[keyCode]
    }
}
