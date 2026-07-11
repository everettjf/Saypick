//
//  TranslationCache.swift
//  Saypick
//
//  简单 LRU 缓存，key = backend|from|to|text。
//

import Foundation

final class TranslationCache {
    static let shared = TranslationCache()

    private let capacity = 200
    private var store: [String: String] = [:]
    private var order: [String] = []
    private let lock = NSLock()

    private init() {}

    func key(backend: String, from: Language?, to: Language, text: String) -> String {
        "\(backend)|\(from?.rawValue ?? "auto")|\(to.rawValue)|\(text)"
    }

    func value(for key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let v = store[key] else { return nil }
        touch(key)
        return v
    }

    func set(_ value: String, for key: String) {
        lock.lock(); defer { lock.unlock() }
        store[key] = value
        touch(key)
        while order.count > capacity {
            let evict = order.removeFirst()
            store[evict] = nil
        }
    }

    private func touch(_ key: String) {
        if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
        order.append(key)
    }
}
