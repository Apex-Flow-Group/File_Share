#include "flutter_window.h"

#include <optional>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <windows.h>
#include <shlobj.h>
#include <objidl.h>
#include <wincodec.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

// ─── Clipboard MethodChannel name (must match Dart side) ─────────────────────
static const char kClipboardChannel[] = "com.apex.core/clipboard";

// ─── Helper: convert wide string to UTF-8 ────────────────────────────────────
static std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                 static_cast<int>(wide.size()),
                                 nullptr, 0, nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                      static_cast<int>(wide.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

// ─── Helper: save DIB (bitmap) from clipboard to a temp PNG file ─────────────
// Returns the file path on success, empty string on failure.
// We save as a BMP first (Windows has no built-in PNG encoder accessible
// without WIC), then rename with .png extension so Flutter can show a preview.
// For actual PNG we use the WIC pipeline available on every Windows 7+ system.
static std::string SaveClipboardImageAsPng() {
  // Get DIB from clipboard
  HANDLE hDib = GetClipboardData(CF_DIB);
  if (!hDib) return {};

  BITMAPINFOHEADER* pBih =
      reinterpret_cast<BITMAPINFOHEADER*>(GlobalLock(hDib));
  if (!pBih) return {};

  // Build a temp file path:  %TEMP%\apex_clip_<tick>.png
  wchar_t tempDir[MAX_PATH];
  if (!GetTempPathW(MAX_PATH, tempDir)) {
    GlobalUnlock(hDib);
    return {};
  }
  ULONGLONG tick = GetTickCount64();
  std::wostringstream oss;
  oss << tempDir << L"apex_clip_" << tick << L".png";
  std::wstring wPath = oss.str();

  // Use WIC to encode PNG
  bool saved = false;
  IWICImagingFactory* pFactory = nullptr;
  IWICBitmapEncoder* pEncoder = nullptr;
  IWICBitmapFrameEncode* pFrame = nullptr;
  IStream* pStream = nullptr;
  IWICStream* pWicStream = nullptr;

  HRESULT hr = CoCreateInstance(
      CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
      IID_IWICImagingFactory, reinterpret_cast<void**>(&pFactory));

  if (SUCCEEDED(hr)) {
    hr = pFactory->CreateStream(&pWicStream);
  }
  if (SUCCEEDED(hr)) {
    hr = pWicStream->InitializeFromFilename(wPath.c_str(), GENERIC_WRITE);
  }
  if (SUCCEEDED(hr)) {
    hr = pFactory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &pEncoder);
  }
  if (SUCCEEDED(hr)) {
    hr = pEncoder->Initialize(pWicStream, WICBitmapEncoderNoCache);
  }
  if (SUCCEEDED(hr)) {
    hr = pEncoder->CreateNewFrame(&pFrame, nullptr);
  }
  if (SUCCEEDED(hr)) {
    hr = pFrame->Initialize(nullptr);
  }

  if (SUCCEEDED(hr)) {
    // Determine pixel format and dimensions from BITMAPINFOHEADER
    UINT width  = static_cast<UINT>(pBih->biWidth);
    UINT height = static_cast<UINT>(abs(pBih->biHeight));
    bool topDown = pBih->biHeight < 0;

    WICPixelFormatGUID pixelFormat = GUID_WICPixelFormat32bppBGRA;
    UINT stride = ((width * 32 + 31) / 32) * 4;

    // Pixel data starts after the BITMAPINFOHEADER (and optional colour table)
    DWORD colorTableSize = 0;
    if (pBih->biClrUsed > 0) {
      colorTableSize = pBih->biClrUsed * static_cast<DWORD>(sizeof(RGBQUAD));
    } else if (pBih->biBitCount <= 8) {
      colorTableSize = static_cast<DWORD>(
          (1ULL << pBih->biBitCount) * sizeof(RGBQUAD));
    }
    const BYTE* pPixels =
        reinterpret_cast<const BYTE*>(pBih) + pBih->biSize + colorTableSize;

    // If biBitCount != 32, fall back to simple BMP save (rare case)
    if (pBih->biBitCount == 32) {
      std::vector<BYTE> rowBuffer(stride);

      hr = pFrame->SetSize(width, height);
      if (SUCCEEDED(hr)) hr = pFrame->SetPixelFormat(&pixelFormat);

      if (SUCCEEDED(hr)) {
        // Write rows (bottom-up DIB → reverse if not topDown)
        for (UINT row = 0; row < height && SUCCEEDED(hr); ++row) {
          UINT srcRow = topDown ? row : (height - 1 - row);
          const BYTE* src = pPixels + srcRow * stride;
          std::copy(src, src + stride, rowBuffer.begin());
          hr = pFrame->WritePixels(1, stride, stride, rowBuffer.data());
        }
      }
      if (SUCCEEDED(hr)) hr = pFrame->Commit();
      if (SUCCEEDED(hr)) hr = pEncoder->Commit();
      saved = SUCCEEDED(hr);
    }
  }

  // Cleanup COM objects
  if (pFrame)     pFrame->Release();
  if (pEncoder)   pEncoder->Release();
  if (pWicStream) pWicStream->Release();
  if (pStream)    pStream->Release();
  if (pFactory)   pFactory->Release();

  GlobalUnlock(hDib);

  if (saved) {
    return WideToUtf8(wPath);
  }

  // Fallback: save as BMP if WIC 32-bit path failed
  // (covers 24-bit screenshots, etc.)
  // Re-read DIB and write a raw BMP
  hDib = GetClipboardData(CF_DIB);
  if (!hDib) return {};
  pBih = reinterpret_cast<BITMAPINFOHEADER*>(GlobalLock(hDib));
  if (!pBih) return {};

  // Use .bmp extension for fallback
  std::wostringstream oss2;
  oss2 << tempDir << L"apex_clip_" << tick << L".bmp";
  std::wstring wBmpPath = oss2.str();

  SIZE_T dibSize = GlobalSize(hDib);
  BITMAPFILEHEADER bfh = {};
  bfh.bfType = 0x4D42; // 'BM'
  DWORD headerAndColorTable =
      pBih->biSize + (pBih->biClrUsed > 0
                          ? pBih->biClrUsed * static_cast<DWORD>(sizeof(RGBQUAD))
                          : (pBih->biBitCount <= 8
                                 ? static_cast<DWORD>((1ULL << pBih->biBitCount) * sizeof(RGBQUAD))
                                 : 0U));
  bfh.bfOffBits  = sizeof(BITMAPFILEHEADER) + headerAndColorTable;
  bfh.bfSize     = sizeof(BITMAPFILEHEADER) + static_cast<DWORD>(dibSize);

  std::ofstream bmpFile(wBmpPath, std::ios::binary);
  bool bmpSaved = false;
  if (bmpFile.is_open()) {
    bmpFile.write(reinterpret_cast<const char*>(&bfh), sizeof(bfh));
    bmpFile.write(reinterpret_cast<const char*>(pBih),
                  static_cast<std::streamsize>(dibSize));
    bmpFile.close();
    bmpSaved = true;
  }
  GlobalUnlock(hDib);

  return bmpSaved ? WideToUtf8(wBmpPath) : std::string{};
}

// ─── FlutterWindow ───────────────────────────────────────────────────────────

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // ── Set up clipboard MethodChannel ──────────────────────────────────────
  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kClipboardChannel,
          &flutter::StandardMethodCodec::GetInstance());

  clipboard_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        // Dart currently sends no calls to C++ on this channel.
        result->NotImplemented();
      });

  // ── Register this window to receive WM_CLIPBOARDUPDATE ──────────────────
  AddClipboardFormatListener(GetHandle());

  // ── Initialize COM (needed for WIC PNG encoding) ─────────────────────────
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveClipboardFormatListener(GetHandle());
  CoUninitialize();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_CLIPBOARDUPDATE: {
      // Only handle if the channel is ready
      if (!clipboard_channel_) break;

      if (!OpenClipboard(nullptr)) break;

      flutter::EncodableMap args;
      bool shouldNotify = false;

      // ── Case 1: Files (CF_HDROP) ──────────────────────────────────────
      if (IsClipboardFormatAvailable(CF_HDROP)) {
        HANDLE hDrop = GetClipboardData(CF_HDROP);
        if (hDrop) {
          UINT fileCount = DragQueryFileW(
              reinterpret_cast<HDROP>(hDrop), 0xFFFFFFFF, nullptr, 0);
          if (fileCount > 0) {
            flutter::EncodableList paths;
            for (UINT i = 0; i < fileCount; ++i) {
              UINT len = DragQueryFileW(
                  reinterpret_cast<HDROP>(hDrop), i, nullptr, 0);
              if (len > 0) {
                std::wstring wpath(len + 1, L'\0');
                DragQueryFileW(reinterpret_cast<HDROP>(hDrop), i,
                               wpath.data(), len + 1);
                wpath.resize(len);
                paths.push_back(
                    flutter::EncodableValue(WideToUtf8(wpath)));
              }
            }
            if (!paths.empty()) {
              args[flutter::EncodableValue("type")] =
                  flutter::EncodableValue("files");
              args[flutter::EncodableValue("paths")] =
                  flutter::EncodableValue(paths);
              shouldNotify = true;
            }
          }
        }
      }
      // ── Case 2: Image / Screenshot (CF_DIB) ──────────────────────────
      else if (IsClipboardFormatAvailable(CF_DIB)) {
        // Save image to temp before closing clipboard
        std::string imgPath = SaveClipboardImageAsPng();
        if (!imgPath.empty()) {
          flutter::EncodableList paths;
          paths.push_back(flutter::EncodableValue(imgPath));
          args[flutter::EncodableValue("type")] =
              flutter::EncodableValue("image");
          args[flutter::EncodableValue("paths")] =
              flutter::EncodableValue(paths);
          shouldNotify = true;
        }
      }
      // ── Case 3: Plain text (CF_UNICODETEXT) ───────────────────────────
      else if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
        HANDLE hText = GetClipboardData(CF_UNICODETEXT);
        if (hText) {
          const wchar_t* pText =
              reinterpret_cast<const wchar_t*>(GlobalLock(hText));
          if (pText) {
            std::wstring wtext(pText);
            GlobalUnlock(hText);

            // Ignore empty or whitespace-only strings
            bool hasContent = false;
            for (wchar_t c : wtext) {
              if (c != L' ' && c != L'\t' && c != L'\r' && c != L'\n') {
                hasContent = true;
                break;
              }
            }

            if (hasContent) {
              // Save as UTF-8 .txt in %TEMP%
              wchar_t tempDir[MAX_PATH];
              std::string txtPath;
              if (GetTempPathW(MAX_PATH, tempDir)) {
                ULONGLONG tick = GetTickCount64();
                std::wostringstream oss;
                oss << tempDir << L"apex_clip_" << tick << L".txt";
                std::wstring wTxtPath = oss.str();

                // Convert to UTF-8 and write
                int utf8Size = WideCharToMultiByte(
                    CP_UTF8, 0, wtext.c_str(),
                    static_cast<int>(wtext.size()),
                    nullptr, 0, nullptr, nullptr);
                std::string utf8Text(utf8Size, '\0');
                WideCharToMultiByte(
                    CP_UTF8, 0, wtext.c_str(),
                    static_cast<int>(wtext.size()),
                    utf8Text.data(), utf8Size, nullptr, nullptr);

                std::ofstream txtFile(wTxtPath, std::ios::binary);
                if (txtFile.is_open()) {
                  txtFile.write(utf8Text.data(), utf8Size);
                  txtFile.close();
                  txtPath = WideToUtf8(wTxtPath);
                }
              }

              if (!txtPath.empty()) {
                flutter::EncodableList paths;
                paths.push_back(flutter::EncodableValue(txtPath));
                args[flutter::EncodableValue("type")] =
                    flutter::EncodableValue("text");
                args[flutter::EncodableValue("paths")] =
                    flutter::EncodableValue(paths);
                // Send preview (first 100 chars) for display in UI
                std::wstring preview = wtext.substr(0, 100);
                if (wtext.size() > 100) {
                  preview += L"...";
                }
                args[flutter::EncodableValue("textPreview")] =
                    flutter::EncodableValue(WideToUtf8(preview));
                shouldNotify = true;
              }
            }
          } else {
            GlobalUnlock(hText);
          }
        }
      }

      CloseClipboard();

      if (shouldNotify && clipboard_channel_) {
        clipboard_channel_->InvokeMethod(
            "onClipboardChanged",
            std::make_unique<flutter::EncodableValue>(
                flutter::EncodableValue(args)));
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
