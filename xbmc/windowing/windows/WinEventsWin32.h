/*
 *  Copyright (C) 2005-2018 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#pragma once

#include "input/touch/TouchTypes.h"
#include "windowing/WinEvents.h"

class CGenericTouchSwipeDetector;

class CWinEventsWin32 : public IWinEvents
{
public:
  // kodi-rt: WM_COPYDATA id for files a second kodi.exe hands to the running one (WinMain.cpp)
  static constexpr ULONG_PTR COPYDATA_OPEN_FILES = 0x4B4F4446; // "KODF"

  bool MessagePump() override;
  static LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

private:
  static void RegisterDeviceInterfaceToHwnd(GUID InterfaceClassGuid, HWND hWnd, HDEVNOTIFY *hDeviceNotify);
  static void WindowFromScreenCoords(HWND hWnd, POINT *point);
  static void OnGestureNotify(HWND hWnd, LPARAM lParam);
  static void OnGesture(HWND hWnd, LPARAM lParam);

  static int m_originalZoomDistance;
  static Pointer m_touchPointer;
  static CGenericTouchSwipeDetector *m_touchSwipeDetector;
};

