unit GDIPng;
interface

uses
  Windows, SysUtils,Classes, Graphics,GR32,GR32_Backends;

procedure Bitmap32ToPNGStream(ABitmap:TBitmap32;Stream: TStream;Transparent:boolean);
procedure Bitmap32FromStream(ABitmap:TBitmap32;Stream: TStream;BGColor:TColor32);
implementation
uses ActiveX;
 type
  GdiplusStartupInput = packed record
    GdiplusVersion          : Cardinal;
    DebugEventCallback      : Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs  : BOOL;
  end;
  TGdiplusStartupInput = GdiplusStartupInput;
  PGdiplusStartupInput = ^TGdiplusStartupInput;
  GPIMAGE     =Pointer;
  GPBITMAP    =Pointer;
  GPGRAPHICS  =Pointer;
const
    DLL='gdiplus.dll';
function GdipSaveImageToStream(image: GPIMAGE;stream: ISTREAM;ClsidEncoder: PGUID;pParams: Pointer): integer; stdcall;external DLL;
function GdipDisposeImage(image: GPIMAGE): integer; stdcall;external DLL;
function GdipCreateBitmapFromScan0(Width,Height,Stride,Format: Integer;Scan0: Pointer; out Bitmap: GPBITMAP):integer; stdcall;external DLL;
function GdiplusStartup(out token: ULONG; input: PGdiplusStartupInput;output: Pointer): Integer; stdcall;external DLL;
function GdiplusShutdown(token: ULONG):integer; stdcall;external DLL;
function GdipCreateBitmapFromStream(stream: ISTREAM;out bitmap: GPBITMAP): integer; stdcall;external DLL;
function GdipDrawImage(graphics: GPGRAPHICS; image: GPIMAGE; x,y: Single): integer; stdcall;external DLL;
function GdipDeleteGraphics(graphics: GPGRAPHICS): Integer; stdcall;external DLL;
function GdipCreateFromHDC(hdc: HDC;out graphics: GPGRAPHICS): integer; stdcall;external DLL;
function GdipGetImageWidth(image: GPIMAGE;var width: UINT): integer; stdcall;external DLL;
function GdipGetImageHeight(image: GPIMAGE;var height: UINT): integer; stdcall;external DLL;

procedure Bitmap32ToPNGStream(ABitmap:TBitmap32;Stream: TStream;Transparent:boolean);
const
  PNGEncoder:TGuid = '{557CF406-1A04-11D3-9A73-0000F81EF32E}';
  PixelFormat32bppARGB  = $26200A;
  PixelFormat32bppRGB  = $22009;
  USESALPHA:array[boolean] of integer=(PixelFormat32bppRGB,PixelFormat32bppARGB);
var
 Str:TStreamAdapter;
 Img:Pointer;
begin
 with ABitmap  do
  if GdipCreateBitmapFromScan0(Width,Height,Width*4,USESALPHA[Transparent],Bits,Img)=0 then
  begin
    Str:=TStreamAdapter.Create(Stream);
    GdipSaveImageToStream(Img,Str as IStream,@PNGEncoder,nil);
    GdipDisposeImage(Img);
  end;
end;

procedure Bitmap32FromStream(ABitmap:TBitmap32;Stream: TStream;BGColor:TColor32);
var
 W,H:Cardinal;
 Img,Gr:Pointer;
begin
  with ABitmap do
    if GdipCreateBitmapFromStream(TStreamAdapter.Create(Stream)as istream, Img)= 0 then
    begin
      GdipGetImageWidth(Img,W);
      GdipGetImageHeight(Img,H);
      SetSize(W,H);
      if DrawMode=dmOpaque  then
         Clear(BGColor);
      GdipCreateFromHDC(Canvas.Handle,Gr);
      GdipDrawImage(Gr,Img,0,0);
      GdipDeleteGraphics(Gr);
      GdipDisposeImage(Img);
    end;
end;

var
  StartupInput: TGDIPlusStartupInput;
  GdiplusToken: ULONG;

initialization
  StartupInput.GdiplusVersion := 1;
  GdiplusStartup(GdiplusToken, @StartupInput, nil);
finalization
  GdiplusShutdown(GdiplusToken);
end.

