/*  converta.cpp — GIF-to-MP4 conversion via the bundled ffmpeg.exe
 *
 *  Design decisions:
 *   - CreateProcess() instead of system() / popen() for full control, error
 *     capture, and no PATH dependency.
 *   - ffmpeg.exe is expected next to converta_core.dll (both copied there by
 *     CMake POST_BUILD rules).
 *   - g_cancel lets the caller kill the ffmpeg process mid-run.
 *   - A Windows named pipe captures stderr so errors are surfaced in
 *     g_last_error without polluting the user's console.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "../include/converta.h"
#include "../include/thread_pool.h"

#include <filesystem>
#include <string>
#include <sstream>
#include <vector>
#include <iostream>

// ─── Module handle so we can locate the DLL on disk ──────────────────────────

static HMODULE g_hModule = nullptr;

BOOL WINAPI DllMain(HINSTANCE hInst, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_hModule = hInst;
    }
    return TRUE;
}

// ─── Shared error state ───────────────────────────────────────────────────────

static std::string g_last_error;

static void set_error(const std::string& msg) {
    g_last_error = msg;
}

// ─── Helper: absolute path of this DLL ───────────────────────────────────────

static std::filesystem::path dll_dir() {
    wchar_t buf[MAX_PATH] = {};
    GetModuleFileNameW(g_hModule, buf, MAX_PATH);
    return std::filesystem::path(buf).parent_path();
}

// ─── Helper: read all data from a HANDLE into a string ───────────────────────

static std::string drain_pipe(HANDLE h) {
    std::string out;
    char buf[4096];
    DWORD read = 0;
    while (ReadFile(h, buf, sizeof(buf), &read, nullptr) && read > 0) {
        out.append(buf, read);
    }
    return out;
}

// ─── Helper: build a properly quoted command-line string ─────────────────────
//
// Windows CreateProcess requires a mutable LPWSTR so we hand back a wstring.
// Each argument is unconditionally quoted and internal double-quotes escaped.

static std::wstring build_cmdline(const std::wstring& exe,
                                  const std::vector<std::wstring>& args) {
    std::wostringstream ss;

    // Quote the executable name
    ss << L'"' << exe << L'"';

    for (const auto& arg : args) {
        ss << L' ';
        // If the arg contains a space or quote, wrap it
        bool needsQuotes = (arg.find_first_of(L" \t\"") != std::wstring::npos);
        if (needsQuotes) {
            ss << L'"';
            for (wchar_t c : arg) {
                if (c == L'"') ss << L'\\';
                ss << c;
            }
            ss << L'"';
        } else {
            ss << arg;
        }
    }

    return ss.str();
}

// ─── Helper: narrow (UTF-8) → wide (UTF-16) ──────────────────────────────────

static std::wstring to_wide(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
    std::wstring w(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, &w[0], n);
    // strip the embedded NUL that MultiByteToWideChar appends
    if (!w.empty() && w.back() == L'\0') w.pop_back();
    return w;
}

// ─── converta_gif_to_mp4 ─────────────────────────────────────────────────────

int32_t converta_gif_to_mp4(
    const char* in,
    const char* out,
    int32_t     crf,
    const char* preset,
    converta_progress_cb cb,
    void*        userdata)
{
    // ── 0. Validate inputs ────────────────────────────────────────────────────
    if (!in || !out) {
        set_error("converta_gif_to_mp4: null path argument");
        return -1;
    }

    std::filesystem::path inputPath(in);
    if (!std::filesystem::exists(inputPath)) {
        set_error(std::string("Input file not found: ") + in);
        return -1;
    }

    // ── 1. Locate bundled ffmpeg.exe (same directory as this DLL) ────────────
    std::filesystem::path ffmpegExe = dll_dir() / "ffmpeg.exe";
    if (!std::filesystem::exists(ffmpegExe)) {
        set_error("ffmpeg.exe not found next to converta_core.dll. "
                  "Rebuild to bundle the binary.");
        return -1;
    }

    // ── 2. Clamp / default parameters ────────────────────────────────────────
    if (crf < 0 || crf > 51) crf = 18;
    std::string safePreset = (preset && *preset) ? preset : "veryfast";

    // Validate preset to prevent injection
    const char* validPresets[] = {
        "ultrafast","superfast","veryfast","faster","fast",
        "medium","slow","slower","veryslow",nullptr
    };
    bool presetOk = false;
    for (int i = 0; validPresets[i]; ++i) {
        if (safePreset == validPresets[i]) { presetOk = true; break; }
    }
    if (!presetOk) safePreset = "veryfast";

    // ── 3. Build the CreateProcess command line ───────────────────────────────
    //
    //  ffmpeg -y -hwaccel auto -threads 0
    //         -i "<input>"
    //         -movflags +faststart
    //         -c:v libx264
    //         -crf <crf>
    //         -preset <preset>
    //         -pix_fmt yuv420p
    //         -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"
    //         "<output>"
    //
    //  -hwaccel auto     → use GPU decoding when available, transparent fallback
    //  -threads 0        → auto-select thread count
    //  pix_fmt yuv420p   → required for broad player compatibility
    //  scale filter      → ensures even dimensions (libx264 constraint)
    //  -movflags faststart → moov atom at front for progressive streaming

    std::wstring crfStr    = std::to_wstring(crf);
    std::wstring presetStr = to_wide(safePreset);
    std::wstring inW       = to_wide(std::string(in));
    std::wstring outW      = to_wide(std::string(out));

    std::vector<std::wstring> args = {
        L"-y",
        L"-hwaccel", L"auto",
        L"-threads",  L"0",
        L"-i",        inW,
        L"-movflags", L"+faststart",
        L"-c:v",      L"libx264",
        L"-crf",      crfStr,
        L"-preset",   presetStr,
        L"-pix_fmt",  L"yuv420p",
        L"-vf",       L"scale=trunc(iw/2)*2:trunc(ih/2)*2",
        outW,
    };

    std::wstring cmdLine = build_cmdline(ffmpegExe.wstring(), args);

    // Debug: log the full command to stdout (visible in debug builds / IDE)
#ifndef NDEBUG
    {
        int len = WideCharToMultiByte(CP_UTF8, 0, cmdLine.c_str(), -1, nullptr, 0, nullptr, nullptr);
        std::string narrow(len, '\0');
        WideCharToMultiByte(CP_UTF8, 0, cmdLine.c_str(), -1, &narrow[0], len, nullptr, nullptr);
        std::cout << "[converta] CMD: " << narrow << std::endl;
    }
#endif

    // ── 4. Set up stderr capture via anonymous pipe ───────────────────────────
    HANDLE hReadStderr  = INVALID_HANDLE_VALUE;
    HANDLE hWriteStderr = INVALID_HANDLE_VALUE;

    SECURITY_ATTRIBUTES sa{};
    sa.nLength              = sizeof(sa);
    sa.bInheritHandle       = TRUE;
    sa.lpSecurityDescriptor = nullptr;

    if (!CreatePipe(&hReadStderr, &hWriteStderr, &sa, 0)) {
        set_error("CreatePipe failed");
        return -1;
    }
    // Make the read end non-inheritable so the child doesn't get confused
    SetHandleInformation(hReadStderr, HANDLE_FLAG_INHERIT, 0);

    // ── 5. Launch ffmpeg ──────────────────────────────────────────────────────
    STARTUPINFOW si{};
    si.cb          = sizeof(si);
    si.dwFlags     = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;          // no console window flashing
    si.hStdInput   = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput  = GetStdHandle(STD_OUTPUT_HANDLE); // progress lines go to parent
    si.hStdError   = hWriteStderr;

    PROCESS_INFORMATION pi{};

    // CreateProcessW demands a mutable buffer for lpCommandLine
    std::vector<wchar_t> cmdBuf(cmdLine.begin(), cmdLine.end());
    cmdBuf.push_back(L'\0');

    BOOL created = CreateProcessW(
        nullptr,
        cmdBuf.data(),
        nullptr, nullptr,
        TRUE,               // inherit handles (the pipe write end)
        CREATE_NO_WINDOW,   // suppress console
        nullptr, nullptr,
        &si, &pi
    );

    // The write end is now inherited by the child; close our copy so
    // ReadFile on the read end EOF's properly when ffmpeg exits.
    CloseHandle(hWriteStderr);

    if (!created) {
        CloseHandle(hReadStderr);
        DWORD err = GetLastError();
        std::string msg = "CreateProcess failed (error " + std::to_string(err) + ")";
        set_error(msg);
        return -1;
    }

    // ── 6. Wait for completion (honouring g_cancel) ───────────────────────────
    while (true) {
        DWORD waitResult = WaitForSingleObject(pi.hProcess, 200 /*ms*/);

        if (g_cancel.load(std::memory_order_relaxed)) {
            TerminateProcess(pi.hProcess, 1);
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            CloseHandle(hReadStderr);
            set_error("Cancelled by user.");
            return -1;
        }

        if (waitResult == WAIT_OBJECT_0) break;  // done
    }

    // ── 7. Collect exit code & stderr ────────────────────────────────────────
    DWORD exitCode = 1;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    std::string stderrText = drain_pipe(hReadStderr);
    CloseHandle(hReadStderr);

    if (exitCode != 0) {
        // FFmpeg writes progress + errors to stderr. Return a trimmed excerpt.
        std::string msg = "ffmpeg exited with code " + std::to_string(exitCode);
        if (!stderrText.empty()) {
            // Last non-empty line is usually the most informative error
            std::istringstream ss(stderrText);
            std::string line, lastNonEmpty;
            while (std::getline(ss, line)) {
                if (!line.empty() && line.find('\r') != 0)
                    lastNonEmpty = line;
            }
            if (!lastNonEmpty.empty())
                msg += ": " + lastNonEmpty;
        }
        set_error(msg);
        return -1;
    }

    // ── 8. Verify output file exists ──────────────────────────────────────────
    if (!std::filesystem::exists(out)) {
        set_error("ffmpeg reported success but output file is missing: " + std::string(out));
        return -1;
    }

    g_last_error.clear();

    // Fire a 100% progress callback if the caller provided one
    if (cb) cb(1.0, userdata);

    return 0;
}

// ─── converta_cancel / converta_last_error ────────────────────────────────────

void converta_cancel(void) {
    g_cancel.store(true, std::memory_order_relaxed);
}

const char* converta_last_error(void) {
    return g_last_error.c_str();
}
