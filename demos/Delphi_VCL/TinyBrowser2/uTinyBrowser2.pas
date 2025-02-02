// ************************************************************************
// ***************************** CEF4Delphi *******************************
// ************************************************************************
//
// CEF4Delphi is based on DCEF3 which uses CEF3 to embed a chromium-based
// browser in Delphi applications.
//
// The original license of DCEF3 still applies to CEF4Delphi.
//
// For more information about CEF4Delphi visit :
//         https://www.briskbard.com/index.php?lang=en&pageid=cef
//
//        Copyright � 2018 Salvador D�az Fau. All rights reserved.
//
// ************************************************************************
// ************ vvvv Original license and comments below vvvv *************
// ************************************************************************
(*
 *                       Delphi Chromium Embedded 3
 *
 * Usage allowed under the restrictions of the Lesser GNU General Public License
 * or alternatively the restrictions of the Mozilla Public License 1.1
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 *
 * Unit owner : Henri Gourvest <hgourvest@gmail.com>
 * Web site   : http://www.progdigy.com
 * Repository : http://code.google.com/p/delphichromiumembedded/
 * Group      : http://groups.google.com/group/delphichromiumembedded
 *
 * Embarcadero Technologies, Inc is not permitted to use or redistribute
 * this source code without explicit permission.
 *
 *)

unit uTinyBrowser2;

{$I cef.inc}

interface

uses
  {$IFDEF DELPHI16_UP}
  System.Types, System.SysUtils,
  {$ELSE}
  Types, SysUtils,
  {$ENDIF}
  uCEFInterfaces, uCEFTypes, uCEFChromiumCore;

type
  TTinyBrowser2 = class
    private
      FChromium : TChromiumCore;

      function GetClient : ICefClient;

      procedure Chromium_OnBeforeClose(Sender: TObject; const browser: ICefBrowser);
      procedure Chromium_OnBeforePopup(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; const targetUrl, targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean; const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo; var client: ICefClient; var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue; var noJavascriptAccess: Boolean; var Result: Boolean);
      procedure Chromium_OnOpenUrlFromTab(Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame; const targetUrl: ustring; targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean; out Result: Boolean);

    public
      constructor Create;
      destructor  Destroy; override;
      procedure   AfterConstruction; override;

      property Client      : ICefClient read GetClient;
  end;

procedure CreateGlobalCEFApp;
procedure DestroyTinyBrowser;

implementation

// This demo is similar to the cefsimple demo in the official CEF project.

// It doesn't use VCL or FMX to create forms from Delphi code.
// It just uses CEF to create a browser window as if it was a popup browser window.

// This browser doesn't use multiple threads to handle the browser and it doesn't use an external message pump.
// For this reason we have to call GlobalCEFApp.RunMessageLoop to let CEF handle the message loop and
// GlobalCEFApp.QuitMessageLoop when the browser has been destroyed.

// The destruction steps are much simpler for that reason.
// In this demo it's only necessary to implement the TChromium.OnClose and TChromium.OnBeforeClose events.
// The TChromium.OnClose event only sets aAction to cbaClose to continue closing the browser.
// The TChromium.OnBeforeClose event calls GlobalCEFApp.QuitMessageLoop because the browser has been destroyed
// and it's necessary to close the message loop.

uses
  uCEFApplication, uCEFConstants, uCEFMiscFunctions;

var
  TinyBrowser : TTinyBrowser2 = nil;

procedure GlobalCEFApp_OnContextInitialized;
begin
  TinyBrowser := TTinyBrowser2.Create;
end;

procedure GlobalCEFApp_OnGetDefaultClient(var aClient : ICefClient);
begin
  aClient := TinyBrowser.Client;
end;

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                            := TCefApplication.Create;
  GlobalCEFApp.MultiThreadedMessageLoop   := False;
  GlobalCEFApp.ExternalMessagePump        := False;
  GlobalCEFApp.ChromeRuntime              := True; // Enable this line to enable the "ChromeRuntime" mode. It's in experimental state.
  GlobalCEFApp.cache                      := 'cache';
  GlobalCEFApp.DisablePopupBlocking       := True;
  GlobalCEFApp.OnContextInitialized       := GlobalCEFApp_OnContextInitialized;
  GlobalCEFApp.OnGetDefaultClient         := GlobalCEFApp_OnGetDefaultClient;    // This event is only used in "ChromeRuntime" mode

  // This is a workaround for the CEF4Delphi issue #324 :
  // https://github.com/salvadordf/CEF4Delphi/issues/324
  GlobalCEFApp.DisableFeatures := 'WinUseBrowserSpellChecker';
end;

procedure DestroyTinyBrowser;
begin
  if (TinyBrowser <> nil) then
    FreeAndNil(TinyBrowser);
end;

constructor TTinyBrowser2.Create;
begin
  inherited Create;

  FChromium := nil;
end;

destructor TTinyBrowser2.Destroy;
begin
  if (FChromium <> nil) then
    FreeAndNil(FChromium);

  inherited Destroy;
end;

procedure TTinyBrowser2.AfterConstruction;
var
  TempHandle : TCefWindowHandle;
  TempRect : TRect;
begin
  inherited AfterConstruction;

  FChromium                  := TChromiumCore.Create(nil);
  FChromium.DefaultURL       := 'https://www.google.com';
  FChromium.OnBeforeClose    := Chromium_OnBeforeClose;
  FChromium.OnBeforePopup    := Chromium_OnBeforePopup;
  FChromium.OnOpenUrlFromTab := Chromium_OnOpenUrlFromTab;

  InitializeWindowHandle(TempHandle);
  FChromium.CreateBrowser(TempHandle, TempRect, 'Tiny Browser 2', nil, nil, True);
end;

function TTinyBrowser2.GetClient : ICefClient;
begin
  if (FChromium <> nil) then
    Result := FChromium.CefClient
   else
    Result := nil;
end;

procedure TTinyBrowser2.Chromium_OnBeforeClose(Sender: TObject; const browser: ICefBrowser);
begin
  GlobalCEFApp.QuitMessageLoop;
end;

procedure TTinyBrowser2.Chromium_OnBeforePopup(Sender: TObject; const browser: ICefBrowser;
  const frame: ICefFrame; const targetUrl, targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo;
  var client: ICefClient; var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue;
  var noJavascriptAccess: Boolean; var Result: Boolean);
begin
  // For simplicity, this demo blocks all popup windows and new tabs
  Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

procedure TTinyBrowser2.Chromium_OnOpenUrlFromTab(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  const targetUrl: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; out Result: Boolean);
begin
  // For simplicity, this demo blocks all popup windows and new tabs
  Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

end.
