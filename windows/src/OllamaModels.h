//
//  OllamaModels.h — Ollama 已装模型列表与默认模型自动纠正
//  （对应 macOS 的 OllamaModelResolver + ModelsSettingsView 数据源）。
//
#pragma once
#include <string>
#include <vector>

namespace ollamamodels {

/// GET /api/tags，返回已安装模型名（阻塞，工作线程调用）。
/// 失败返回空并填 error。
std::vector<std::wstring> ListInstalled(std::wstring* error);

/// 配置的 Ollama 模型未安装时自动改成第一个已装模型（避免开箱即败）。
/// 阻塞；返回 true 表示发生了替换（已写回设置）。
bool EnsureValidDefault();

} // namespace ollamamodels
