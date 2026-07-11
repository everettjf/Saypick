#include "Util.h"
#include <cstdarg>
#include <cstdio>

namespace util {

void Log(const char* fmt, ...) {
    static int enabled = -1;
    if (enabled < 0) {
        wchar_t buf[8]{};
        enabled = GetEnvironmentVariableW(L"SAYPICK_DEBUG", buf, 8) > 0 ? 1 : 0;
    }
    if (!enabled) return;

    FILE* f = nullptr;
    _wfopen_s(&f, (AppDataDir() + L"\\debug.log").c_str(), L"ab");
    if (!f) return;
    SYSTEMTIME st;
    GetLocalTime(&st);
    fprintf(f, "%02d:%02d:%02d.%03d [%lu] ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
            GetCurrentThreadId());
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    fprintf(f, "\n");
    fclose(f);
}

} // namespace util
