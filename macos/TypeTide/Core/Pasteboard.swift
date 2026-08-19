//
//  Pasteboard.swift
//  TypeTide
//
//  剪贴板快照/还原，避免取词/粘贴污染用户剪贴板。
//

import AppKit

enum PasteboardHelper {
    /// 深拷贝当前剪贴板所有 item。
    static func snapshot(from pb: NSPasteboard = .general) -> [NSPasteboardItem] {
        var items: [NSPasteboardItem] = []
        for item in pb.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            items.append(copy)
        }
        return items
    }

    static func restore(_ items: [NSPasteboardItem], to pb: NSPasteboard = .general) {
        pb.clearContents()
        if !items.isEmpty {
            pb.writeObjects(items)
        }
    }
}
