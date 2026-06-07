#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

static const wchar_t* kRegKey = L"Software\\ApexFlow\\ApexFileShare";

static void SaveWindowState(HWND hwnd) {
  if (!hwnd || !::IsWindow(hwnd)) return;

  WINDOWPLACEMENT wp = {};
  wp.length = sizeof(WINDOWPLACEMENT);
  if (!::GetWindowPlacement(hwnd, &wp)) return;

  HKEY key;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRegKey, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }

  DWORD maximized = (wp.showCmd == SW_SHOWMAXIMIZED) ? 1 : 0;
  ::RegSetValueExW(key, L"Maximized", 0, REG_DWORD,
                   reinterpret_cast<const BYTE*>(&maximized), sizeof(DWORD));

  if (wp.showCmd != SW_SHOWMAXIMIZED) {
    HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    double scale = dpi / 96.0;

    RECT& r = wp.rcNormalPosition;
    DWORD x = static_cast<DWORD>(static_cast<int>(r.left / scale));
    DWORD y = static_cast<DWORD>(static_cast<int>(r.top / scale));
    DWORD w = static_cast<DWORD>(static_cast<int>((r.right - r.left) / scale));
    DWORD h = static_cast<DWORD>(static_cast<int>((r.bottom - r.top) / scale));
    ::RegSetValueExW(key, L"X", 0, REG_DWORD,
                     reinterpret_cast<const BYTE*>(&x), sizeof(DWORD));
    ::RegSetValueExW(key, L"Y", 0, REG_DWORD,
                     reinterpret_cast<const BYTE*>(&y), sizeof(DWORD));
    ::RegSetValueExW(key, L"W", 0, REG_DWORD,
                     reinterpret_cast<const BYTE*>(&w), sizeof(DWORD));
    ::RegSetValueExW(key, L"H", 0, REG_DWORD,
                     reinterpret_cast<const BYTE*>(&h), sizeof(DWORD));
  }

  ::RegCloseKey(key);
}

static bool LoadWindowState(Win32Window::Point& origin, Win32Window::Size& size,
                            bool& maximized) {
  HKEY key;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRegKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }

  auto readDword = [&](const wchar_t* name, DWORD& out) -> bool {
    DWORD data, dataSize = sizeof(DWORD);
    if (::RegQueryValueExW(key, name, nullptr, nullptr,
                           reinterpret_cast<BYTE*>(&data),
                           &dataSize) == ERROR_SUCCESS) {
      out = data;
      return true;
    }
    return false;
  };

  DWORD x = 0, y = 0, w = 1280, h = 720, max = 0;
  bool ok = readDword(L"X", x) && readDword(L"Y", y) &&
            readDword(L"W", w) && readDword(L"H", h);
  readDword(L"Maximized", max);
  maximized = (max == 1);

  ::RegCloseKey(key);

  if (!ok) return false;

  // Ensure window is visible on screen
  int screenW = ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  int screenH = ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  int screenX = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  int screenY = ::GetSystemMetrics(SM_YVIRTUALSCREEN);

  if (static_cast<int>(x) < screenX) x = static_cast<DWORD>(screenX);
  if (static_cast<int>(y) < screenY) y = static_cast<DWORD>(screenY);
  if (static_cast<int>(x) > screenX + screenW - 100)
    x = static_cast<DWORD>(screenX + screenW / 2 - 640);
  if (static_cast<int>(y) > screenY + screenH - 100)
    y = static_cast<DWORD>(screenY + screenH / 2 - 360);

  if (w < 400) w = 400;
  if (h < 300) h = 300;

  origin = Win32Window::Point(x, y);
  size = Win32Window::Size(w, h);
  return true;
}

static HWND g_main_hwnd = nullptr;
static WNDPROC g_original_wndproc = nullptr;

static LRESULT CALLBACK SaveOnCloseProc(HWND hwnd, UINT msg, WPARAM wp,
                                        LPARAM lp) noexcept {
  if (msg == WM_CLOSE) {
    SaveWindowState(hwnd);
  }
  return ::CallWindowProcW(g_original_wndproc, hwnd, msg, wp, lp);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  bool maximized = false;
  LoadWindowState(origin, size, maximized);

  if (!window.Create(L"Apex File Share", origin, size)) {
    return EXIT_FAILURE;
  }

  g_main_hwnd = window.GetHandle();
  g_original_wndproc = reinterpret_cast<WNDPROC>(
      ::SetWindowLongPtrW(g_main_hwnd, GWLP_WNDPROC,
                          reinterpret_cast<LONG_PTR>(SaveOnCloseProc)));

  if (maximized) {
    ::ShowWindow(g_main_hwnd, SW_SHOWMAXIMIZED);
  }

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
