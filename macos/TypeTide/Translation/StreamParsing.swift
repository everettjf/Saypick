import Foundation

struct StreamingLineAssembler {
    private var buffer = Data()
    private var checkedBOM = false

    mutating func feed(_ data: Data) -> [String] {
        var incoming = data
        if !checkedBOM {
            checkedBOM = true
            if incoming.starts(with: [0xEF, 0xBB, 0xBF]) { incoming.removeFirst(3) }
        }
        buffer.append(incoming)
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            var lineData = buffer[..<newline]
            buffer.removeSubrange(...newline)
            if lineData.last == 0x0D { lineData = lineData.dropLast() }
            if !lineData.isEmpty, let line = String(data: lineData, encoding: .utf8) { lines.append(line) }
        }
        return lines
    }

    mutating func finish() -> [String] {
        defer { buffer.removeAll(keepingCapacity: false) }
        if buffer.last == 0x0D { buffer.removeLast() }
        guard !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) else { return [] }
        return [line]
    }
}

enum OpenAISSEDecoder {
    static func content(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]", let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty else { return nil }
        return content
    }
}
