//
//  OllamaModels.h — Ollama 已装模型列表与默认模型自动纠正
//  （对应 macOS 的 OllamaModelResolver + ModelsSettingsView 数据源）。
//
//  线程约定：Settings 只在主线程读写。异步接口在调用线程拍好
//  host/port 快照带进工作线程，结果 PostMessage 回主线程处理。
//
#pragma once
#include <windows.h>
#include <string>
#include <vector>

namespace ollamamodels {

/// GET {host}:{port}/api/tags，返回已安装模型名（阻塞；host/port 由调用方快照传入）。
/// 失败返回空并填 error。
std::vector<std::wstring> ListInstalled(const std::string& host, int port, std::wstring* error);

/// 异步拉取模型列表：主线程调用（内部拍 Settings 快照），完成后向 notify 投递
/// message（lParam = new std::vector<std::wstring>*，接收方释放）。
void FetchInstalledAsync(HWND notify, UINT message);

/// 主线程调用：给定已装模型列表，配置的模型未安装时改成第一个已装的并保存。
/// 返回 true 表示发生了替换。
bool ApplyResolvedModels(const std::vector<std::wstring>& installed);

/// 同步版自动纠正（自检用；网络阻塞，勿在主线程调）。
bool EnsureValidDefault();

} // namespace ollamamodels
