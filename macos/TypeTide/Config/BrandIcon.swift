//
//  BrandIcon.swift
//  TypeTide
//
//  应用统一品牌符号：点阵汇聚成潮头，对应 Type + Tide。
//

import AppKit

enum BrandIcon {
    /// Asset Catalog 中的单色模板图；会自动适配浅色/深色菜单栏和强调色。
    static let templateImage: NSImage = {
        let image = NSImage(named: "BrandMark")
            ?? NSImage(systemSymbolName: "water.waves", accessibilityDescription: "TypeTide")!
        image.isTemplate = true
        image.accessibilityDescription = "TypeTide"
        return image
    }()
}
