#include "Json.h"
#include <cctype>
#include <cmath>
#include <cstdio>

namespace json {

namespace {

struct Parser {
    const char* p;
    const char* end;
    bool ok = true;

    void skipWs() {
        while (p < end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
    }

    bool consume(char c) {
        skipWs();
        if (p < end && *p == c) { ++p; return true; }
        return false;
    }

    Value parseValue() {
        skipWs();
        if (p >= end) { ok = false; return {}; }
        switch (*p) {
        case '{': return parseObject();
        case '[': return parseArray();
        case '"': return Value(parseString());
        case 't': return parseLit("true", Value(true));
        case 'f': return parseLit("false", Value(false));
        case 'n': return parseLit("null", Value());
        default: return parseNumber();
        }
    }

    Value parseLit(const char* lit, Value v) {
        size_t n = strlen(lit);
        if ((size_t)(end - p) >= n && memcmp(p, lit, n) == 0) { p += n; return v; }
        ok = false; return {};
    }

    Value parseNumber() {
        char* endp = nullptr;
        double d = strtod(p, &endp);
        if (endp == p) { ok = false; return {}; }
        p = endp;
        return Value(d);
    }

    void appendUtf8(std::string& out, unsigned cp) {
        if (cp < 0x80) out += (char)cp;
        else if (cp < 0x800) {
            out += (char)(0xC0 | (cp >> 6));
            out += (char)(0x80 | (cp & 0x3F));
        } else if (cp < 0x10000) {
            out += (char)(0xE0 | (cp >> 12));
            out += (char)(0x80 | ((cp >> 6) & 0x3F));
            out += (char)(0x80 | (cp & 0x3F));
        } else {
            out += (char)(0xF0 | (cp >> 18));
            out += (char)(0x80 | ((cp >> 12) & 0x3F));
            out += (char)(0x80 | ((cp >> 6) & 0x3F));
            out += (char)(0x80 | (cp & 0x3F));
        }
    }

    unsigned parseHex4() {
        unsigned v = 0;
        for (int i = 0; i < 4 && p < end; ++i, ++p) {
            char c = *p;
            v <<= 4;
            if (c >= '0' && c <= '9') v |= c - '0';
            else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10;
            else { ok = false; return 0; }
        }
        return v;
    }

    std::string parseString() {
        std::string out;
        if (p >= end || *p != '"') { ok = false; return out; }
        ++p;
        while (p < end && *p != '"') {
            if (*p == '\\') {
                ++p;
                if (p >= end) { ok = false; break; }
                switch (*p) {
                case '"': out += '"'; ++p; break;
                case '\\': out += '\\'; ++p; break;
                case '/': out += '/'; ++p; break;
                case 'b': out += '\b'; ++p; break;
                case 'f': out += '\f'; ++p; break;
                case 'n': out += '\n'; ++p; break;
                case 'r': out += '\r'; ++p; break;
                case 't': out += '\t'; ++p; break;
                case 'u': {
                    ++p;
                    unsigned cp = parseHex4();
                    // 代理对
                    if (cp >= 0xD800 && cp <= 0xDBFF && end - p >= 6 && p[0] == '\\' && p[1] == 'u') {
                        p += 2;
                        unsigned lo = parseHex4();
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                    }
                    appendUtf8(out, cp);
                    break;
                }
                default: ok = false; ++p; break;
                }
            } else {
                out += *p++;
            }
        }
        if (p < end && *p == '"') ++p; else ok = false;
        return out;
    }

    Value parseObject() {
        ++p; // '{'
        Object obj;
        skipWs();
        if (consume('}')) return Value(std::move(obj));
        while (ok) {
            skipWs();
            std::string key = parseString();
            if (!ok || !consume(':')) { ok = false; break; }
            obj[key] = parseValue();
            if (!ok) break;
            if (consume(',')) continue;
            if (consume('}')) break;
            ok = false;
        }
        return Value(std::move(obj));
    }

    Value parseArray() {
        ++p; // '['
        Array arr;
        skipWs();
        if (consume(']')) return Value(std::move(arr));
        while (ok) {
            arr.push_back(parseValue());
            if (!ok) break;
            if (consume(',')) continue;
            if (consume(']')) break;
            ok = false;
        }
        return Value(std::move(arr));
    }
};

void dumpValue(const Value& v, std::string& out) {
    switch (v.type()) {
    case Value::Type::Null: out += "null"; break;
    case Value::Type::Bool: out += v.asBool() ? "true" : "false"; break;
    case Value::Type::Number: {
        double d = v.asNumber();
        char buf[32];
        if (d == std::floor(d) && std::fabs(d) < 1e15)
            snprintf(buf, sizeof(buf), "%lld", (long long)d);
        else
            snprintf(buf, sizeof(buf), "%.17g", d);
        out += buf;
        break;
    }
    case Value::Type::String: out += Escape(v.asString()); break;
    case Value::Type::Object: {
        out += '{';
        bool first = true;
        for (auto& [k, val] : *v.object()) {
            if (!first) out += ',';
            first = false;
            out += Escape(k);
            out += ':';
            dumpValue(val, out);
        }
        out += '}';
        break;
    }
    case Value::Type::Array: {
        out += '[';
        bool first = true;
        for (auto& item : *v.array()) {
            if (!first) out += ',';
            first = false;
            dumpValue(item, out);
        }
        out += ']';
        break;
    }
    }
}

} // namespace

std::string Value::dump() const {
    std::string out;
    dumpValue(*this, out);
    return out;
}

Value Parse(const std::string& text, bool* okOut) {
    Parser parser{text.data(), text.data() + text.size()};
    Value v = parser.parseValue();
    parser.skipWs();
    if (okOut) *okOut = parser.ok;
    return parser.ok ? v : Value();
}

std::string Escape(const std::string& s) {
    std::string out = "\"";
    for (unsigned char c : s) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\b': out += "\\b"; break;
        case '\f': out += "\\f"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (c < 0x20) {
                char buf[8];
                snprintf(buf, sizeof(buf), "\\u%04x", c);
                out += buf;
            } else {
                out += (char)c;
            }
        }
    }
    out += '"';
    return out;
}

} // namespace json
