//
//  Json.h — 极简 JSON 解析/序列化（无第三方依赖）。
//  支持 object/array/string/number/bool/null，UTF-8 输入输出。
//
#pragma once
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace json {

class Value;
using Object = std::map<std::string, Value>;
using Array = std::vector<Value>;

class Value {
public:
    enum class Type { Null, Bool, Number, String, Object, Array };

    Value() : type_(Type::Null) {}
    Value(bool b) : type_(Type::Bool), bool_(b) {}
    Value(double d) : type_(Type::Number), num_(d) {}
    Value(int i) : type_(Type::Number), num_(i) {}
    Value(const char* s) : type_(Type::String), str_(s) {}
    Value(std::string s) : type_(Type::String), str_(std::move(s)) {}
    Value(Object o) : type_(Type::Object), obj_(std::make_shared<Object>(std::move(o))) {}
    Value(Array a) : type_(Type::Array), arr_(std::make_shared<Array>(std::move(a))) {}

    Type type() const { return type_; }
    bool isNull() const { return type_ == Type::Null; }
    bool isString() const { return type_ == Type::String; }
    bool isObject() const { return type_ == Type::Object; }
    bool isArray() const { return type_ == Type::Array; }

    bool asBool(bool def = false) const { return type_ == Type::Bool ? bool_ : def; }
    double asNumber(double def = 0) const { return type_ == Type::Number ? num_ : def; }
    int asInt(int def = 0) const { return type_ == Type::Number ? (int)num_ : def; }
    const std::string& asString() const { static std::string empty; return type_ == Type::String ? str_ : empty; }

    /// object[key]；不存在或非 object 时返回 Null 值引用
    const Value& operator[](const std::string& key) const {
        static Value null;
        if (type_ != Type::Object || !obj_) return null;
        auto it = obj_->find(key);
        return it == obj_->end() ? null : it->second;
    }
    const Value& at(size_t i) const {
        static Value null;
        if (type_ != Type::Array || !arr_ || i >= arr_->size()) return null;
        return (*arr_)[i];
    }
    size_t size() const {
        if (type_ == Type::Array && arr_) return arr_->size();
        if (type_ == Type::Object && obj_) return obj_->size();
        return 0;
    }
    const Object* object() const { return type_ == Type::Object ? obj_.get() : nullptr; }
    const Array* array() const { return type_ == Type::Array ? arr_.get() : nullptr; }

    std::string dump() const;

private:
    Type type_;
    bool bool_ = false;
    double num_ = 0;
    std::string str_;
    std::shared_ptr<Object> obj_;
    std::shared_ptr<Array> arr_;
};

/// 解析失败返回 Null（ok 置 false）。
Value Parse(const std::string& text, bool* ok = nullptr);

/// 字符串转义（含引号）
std::string Escape(const std::string& s);

} // namespace json
