unit UTxtToPath;

interface

uses
  Windows, SysUtils, Classes,Graphics,GR32,GR32_Paths,math;

type
  TWrapWordKind=(wwNone,wwSplit,wwWrap);
  TTxtAlignement=(tacLeft,tacCenter,tacRight,tacJustify);
  TArrayOfInteger=array of Integer;
  TArrayOfWord=array of Word;


  TTxtGlyphs = class
  protected
    FAdvs:TArrayOfInteger;
    FTextMetric:TTextMetricW;
    FAttrs:TArrayOfWord;
    FGlyphs:TArrayOfWord;
    FCount:integer;
    FRowCount:integer;
    FCurrOffsetX:Double;// precision for text justification
    FDc:HDC;
    function GetTextSize: TSize;
    function TrackLine(var P: PWidechar; var AOut: widestring): boolean;
    procedure SetDC(const Value: HDC);
    function WrapTxt(Start:integer;var lpnFit: Integer): TWrapWordKind;
    procedure PackMerged(const AStr:widestring);
    procedure PrepareTxt();
    procedure AddGlyph(Index, AlignHoriz:integer);
    function JustRow(First, Last: integer):boolean;
    procedure AlignRow(First, Last: integer);
    procedure BuildGlyph(ADC:HDC;Glyph:integer;const X,Y:Double);virtual;
  public
    Measuring:boolean;
    TxtAlignement:TTxtAlignement;
    MaxExtent: integer;
    procedure ProcessLines(const AStr: widestring);
    procedure ProcessLine(const AStr: widestring);
    property DC:HDC read FDC write SetDC;
    property TxtSize:TSize read GetTextSize;
  end;

  TArrayOfGlyphs=array of TArrayOfArrayOfFloatPoint;
  TGRTxtGlyphs=class(TTxtGlyphs)
  protected
    Mat:TMat2;
    FRet:TArrayOfGlyphs;
    FPath:TFlattenedPath;
    FX,FY:TFloat;
    procedure BuildGlyph(ADC:HDC;Glyph:integer;const X,Y:Double);override;
  public
    constructor Create;
    destructor Destroy();override;
  end;
  function ScriptToPath(const AStr:widestring;AFont:TFont;const ADest:TFloatRect;
                    ATxtAlignement:TTxtAlignement):TArrayOfGlyphs;
  function ScriptToMeasure(const AStr: widestring; AFont: TFont;
                  const ADest:TFloatRect; ATxtAlignement: TTxtAlignement): TFLoatRect;
implementation


function GetCharacterPlacementW(DC: HDC; p2: PWideChar; p3, p4: Integer;
  var p5: TGCPResultsW; p6: DWORD): DWORD; stdcall;external 'gdi32.dll';
type
  TJustItem=record
     mStart:integer;
     mEnd:integer;
  end;
  TArrayOfJustItem=array of TJustItem;

procedure TTxtGlyphs.AddGlyph(Index,AlignHoriz:integer);
var
 Y:integer;
begin
  Y:=FTextMetric.tmHeight*(FRowCount-1);
  BuildGlyph(Dc,FGlyphs[Index],FCurrOffsetX+AlignHoriz,Y);
  FCurrOffsetX:=FCurrOffsetX+FAdvs[Index];
end;

procedure TTxtGlyphs.PackMerged(const AStr:widestring);
var
  Ret:TGCPResultsW;
  I,L,Prv,Pz:integer;
  Chars:array of WideChar;
  Orders:TArrayOfInteger;
begin
  L:=Length(AStr);
  Setlength(Orders,L);
  Setlength(FGlyphs,L);
  Setlength(FAdvs,L);
  fillchar(Ret,sizeof(Ret),0);
  Ret.lStructSize:=sizeof(Ret);
  Ret.lpGlyphs:=@FGlyphs[0];
  Ret.lpDx:=@FAdvs[0];
  Ret.nGlyphs:=L;
  Ret.lpOrder:=@Orders[0];
  GetCharacterPlacementW(Dc,@AStr[1],L,0,Ret,GCP_REORDER);
  Setlength(Chars,L);
  Prv:=-1;
  FCount:=0;
  for I := 0 to L - 1 do
  begin
    Pz:=Orders[I];
    if Prv=Pz  then
       continue;
    Chars[Pz]:=AStr[I+1] ;
    Prv:=Pz;
    Inc(FCount);
  end;
  Setlength(FAdvs,FCount);
  Setlength(FGlyphs,FCount);
  Setlength(FAttrs,FCount);
  GetStringTypeExW(0,CT_CTYPE2,@Chars[0],FCount,FAttrs[0]);
end;

function TTxtGlyphs.WrapTxt(Start:integer;var lpnFit:Integer):TWrapWordKind;
const
  BREAKS=[C2_EUROPESEPARATOR,C2_WHITESPACE,C2_OTHERNEUTRAL];
var
 I,Adv,ValidBreak:integer;
 LastAttr,attr:byte;
begin
 ValidBreak:=-1;
 lpnFit:=Start;
 Adv:= FAdvs[Start];
 LastAttr:=FAttrs[Start];
 for I := Start+1 to FCount-1 do
 begin
    Adv :=Adv+FAdvs[I];
    if Adv >= MaxExtent  then
    begin
       if (ValidBreak<>-1) then
       begin
          lpnFit:=ValidBreak;
          Result:=wwWrap;
       end else
          Result:=wwSplit;
       Exit;
    end;
    attr:=FAttrs[I];
    if (attr <> LastAttr)or(attr in BREAKS)then
    begin
       ValidBreak:=I;
       LastAttr:=attr;
       if attr<>C2_WHITESPACE then
           dec(ValidBreak);
       continue;
    end;
    lpnFit:= I;
 end;
 Result:=wwNone;
 lpnFit:= FCount-1;
end;
function TTxtGlyphs.JustRow(First,Last: integer):boolean;
var
  Len,Pos1,D:integer;
  C,OldChar,I:integer;
  Delta,TxtWidth:integer;
  ErrRem:Double;
  Items:TArrayOfJustItem;
  procedure Add(APos,AEnd:integer);
  begin
      Items[Len].mStart:=APos;
      Items[Len].mEnd:=AEnd;
      Inc(Len);
  end;
begin
   Result:=False;
   Len:=Last-First;
   if Len=0 then
      Exit;
   Setlength(Items,Len);
   Pos1:=First;
   TxtWidth:=0;
   Len:=0;
   OldChar:=1;
   while (First<Last)and( FAttrs[First] = C2_WHITESPACE) do
   begin    //add space leads only for first Row
      TxtWidth :=TxtWidth+FAdvs[First];
      Inc(First);
   end;
   for I := First to Last do
   begin
      C:=Ord(FAttrs[I]<>C2_WHITESPACE);
      if C = 1 then    //not a space
         TxtWidth :=TxtWidth+FAdvs[I];
      if (C <> OldChar) then
      begin
         if C=0 then
           Add(Pos1,I-1)
         else
           Pos1:=I;
      end;
      OldChar :=C;
   end;
   if OldChar=1 then
      Add(Pos1,Last);
  // SetLength(Items,Len);
   Len:=Len-1;
   if Len< 1  then
     Exit;
   Result:=True;
   Delta:=MaxExtent-TxtWidth;
   ErrRem:= Delta / Len;
   for I:=0 to Len do
    with Items[I] do
    begin
      for D := mStart to mEnd do
        AddGlyph(D,0);
      FCurrOffsetX:=FCurrOffsetX+ErrRem;
    end;
end;
procedure TTxtGlyphs.AlignRow(First,Last: integer);
var
 Width,I:integer;
begin
    Width:=0;
    if TxtAlignement in [tacRight,tacCenter] then
    begin
      for I := First to Last do
        Width :=Width+FAdvs[I];
      case TxtAlignement of
        tacRight:Width:=MaxExtent-Width;
       tacCenter:Width:=(MaxExtent-Width)div 2;
      end;
    end;
    for I := First to Last do
       AddGlyph(I,Width);
end;
procedure TTxtGlyphs.PrepareTxt();
var
 Curr,Nxt,Last:integer;
 W:TWrapWordKind;
 Justified:boolean;
begin
 Curr:=0;
 repeat
      inc(FRowCount);
      if Curr >= FCount then
         break;
      W:=WrapTxt(Curr,Nxt);
      Last:=Nxt;
      while (Curr < Last)and (FAttrs[Last] = C2_WHITESPACE) do
         Dec(Last);
     // FOffsetX:=FTextMetric.tmAveCharWidth div 2;
      FCurrOffsetX:=0;
      if not Measuring then
      begin
        Justified:=False;
        if (W=wwWrap)and(TxtAlignement=tacJustify) then
           Justified:=JustRow(Curr,Last);
        if not Justified  then
           AlignRow(Curr,Last);
      end;
      if W=wwNone then
         break;
      Curr:=Nxt+1;
      while(FAttrs[Curr] = C2_WHITESPACE) do
        Inc(Curr);
 until False;
end;

function TTxtGlyphs.TrackLine(var P: PWidechar;var AOut:widestring):boolean;
var
  Start: PWidechar;
  W:integer;
begin
  Start := P;
  if P <> nil then
  begin
    repeat
      W:=Ord(P^);
      if(W=10)or(W=13)or(W=0)then
         break;
      Inc(P);
    until False;
    SetString(AOut, Start, P - Start);
    if Ord(P^) = 13 then
       Inc(P);
    if Ord(P^) = 10 then
       Inc(P);
  end;
  Result:=Start <> P;
end;

procedure TTxtGlyphs.ProcessLine(const AStr: widestring);
var
  P:PWideChar;
  S,Txt:Widestring;
begin
  FRowCount:=0;
  Txt:='';
  P:=PWideChar(AStr);
  while TrackLine(P,S) do
    Txt:=Txt+' '+S;
  if Txt='' then
     Exit;
  PackMerged(Txt);
  PrepareTxt();
end;

procedure TTxtGlyphs.ProcessLines(const AStr: widestring);
var
  P:PWideChar;
  S:Widestring;
begin
  FRowCount:=0;
  P:=PWideChar(AStr);
  while TrackLine(P,S) do
  begin
     PackMerged(S);
     PrepareTxt();
  end;
end;

procedure TTxtGlyphs.SetDC(const Value: HDC);
begin
  FDC := Value;
  if FDC=0 then
     Exit;
  GetTextMetricsW(FDC,FTextMetric);
end;

function TTxtGlyphs.GetTextSize: TSize;
begin
   if FRowCount=0 then
   begin
      Result.cx:=0;
      Result.cy:=0;
   end else begin
      Result.cy:=FTextMetric.tmHeight*FRowCount;
      if FRowCount=1 then
         Result.cx:=Round(FCurrOffsetX+0.49)//Ceil
      else
         Result.cx:=MaxExtent;
   end;
end;

procedure TTxtGlyphs.BuildGlyph(ADC: HDC;Glyph:integer;const X,Y:Double);
begin
  windows.ExtTextOut(ADC,Round(X),Round(Y),ETO_GLYPH_INDEX,nil,@Glyph,1,nil);
end;

type
   TRefCanvas=class(TCanvas);
{ TGRTxtGlyphs }
constructor TGRTxtGlyphs.Create;
begin
  FPath:=TFlattenedPath.Create;
  Fillchar(Mat,sizeof(Mat),0);
  Mat.eM11.value:=1;
  Mat.eM22.value:=-1;
end;


destructor TGRTxtGlyphs.Destroy;
begin
  FPath.Free;
  inherited;
end;

var
  gg:integer;
procedure TGRTxtGlyphs.BuildGlyph(ADC: HDC; Glyph: integer; const X, Y: Double);
const
  GGO_BEZIER=3;
var
  CharPos:TFloatPoint;
  function toFloatPoint(const Pt: TPointFX): TFloatPoint;
  begin
    Result.X := CharPos.X+ Integer(Pt.X)* FixedToFloat;
    Result.Y := CharPos.Y+ Integer(Pt.Y)* FixedToFloat;
  end;
  function ConvToPts(const A:TTPolyCurve):TArrayOfFloatPoint;
  var
    I:integer;
  begin
    Setlength(Result,A.cpfx);
    for I:=0 to A.cpfx-1 do
     Result[I]:=toFloatPoint(A.apfx[I]);
  end;
var
  GlyphMetrics:TGlyphMetrics;
  P:Pointer;
  Len:integer;
  Sz,idx,i,t:integer;
  Px:PTTPolygonHeader;
  pPolys:PTTPolyCurve;
  Pts:TArrayOfFloatPoint;
begin
  CharPos:=FloatPoint(FX+X,FY+Y );
  Len:= GetGlyphOutlineW(adc,Glyph,GGO_BEZIER or GGO_GLYPH_INDEX ,GlyphMetrics,0,nil,Mat);
  if Len=-1 then
     Exit;
  Getmem(P,Len);
  GetGlyphOutlineW(adc,Glyph,GGO_BEZIER or GGO_GLYPH_INDEX ,GlyphMetrics,Len,P,Mat);
  Px:=P;
  pPolys:=P;
  FPath.Clear;
  FPath.BeginUpdate;
  repeat
    t:= px.cb;
    with toFloatPoint(Px.pfxStart) do
        FPath.MoveTo(x,y);
    inc(PByte(pPolys),sizeof(TTTPolygonHeader));
    repeat
       Pts :=ConvToPts(pPolys^);
       if pPolys.wType= TT_PRIM_LINE then
       begin   //lines
           FPath.PolyLine(Pts)
       end else begin
          for i:= 0 to pPolys.cpfx div 3 -1 do
          begin
            idx:=I*3;
            FPath.Curveto(Pts[idx],Pts[idx+1],Pts[idx+2]) ;
          end;
       end;
       Sz:=pPolys.cpfx*Sizeof(TPointFX)+4;
       inc(PByte(pPolys),Sz);
       t:=t-Sz;
    until t<= Sizeof(TTTPolygonHeader);
    with toFloatPoint(Px.pfxStart) do
      FPath.LineTo(x,y);
    Px:= Pointer(pPolys);
    FPath.EndPath(True);
  until Integer(Px) >= integer(P)+Len;
  FPath.EndUpdate;
  Freemem(P);
  t:=Length(FRet);
  Setlength(FRet,t+1);
  FRet[t]:=FPath.Path;
  inc(gg);
end;

procedure InternalScriptToPath(const AStr: widestring; AFont: TFont;
    const ADest:TFloatRect; ATxtAlignement: TTxtAlignement;ACalc:boolean;
    var AOut:TArrayOfGlyphs;var ASize:TSize);
var
 Canvas:TCanvas;
begin
   with TGRTxtGlyphs.Create  do
   try
      MaxExtent:= Round(ADest.Right-ADest.Left);
      FX:=ADest.Left;
      FY:=ADest.Top;
      TxtAlignement:=ATxtAlignement;
      Measuring:=ACalc;
      Canvas:=TCanvas.Create;
      Canvas.Handle:=GetDc(0);
      Canvas.Font:=AFont;
      DC:=Canvas.Handle;
      TRefCanvas(Canvas).RequiredState([csHandleValid, csFontValid]);
      ProcessLines(AStr);
      AOut:=FRet;
      ASize:=TxtSize;
      Canvas.Free;
      ReleaseDC(0, DC);
   finally
      Free;
   end;
end;

function ScriptToPath(const AStr: widestring; AFont: TFont;
  const ADest:TFloatRect; ATxtAlignement: TTxtAlignement): TArrayOfGlyphs;
var
  Sz:TSize;
begin
    InternalScriptToPath(AStr,AFont,ADest,ATxtAlignement,False,Result,Sz);
end;

function ScriptToMeasure(const AStr: widestring; AFont: TFont;
  const ADest:TFloatRect; ATxtAlignement: TTxtAlignement): TFLoatRect;
var
  Sz:TSize;
  Ret:TArrayOfGlyphs;
begin
    InternalScriptToPath(AStr,AFont,ADest,ATxtAlignement,False,Ret,Sz);
    Result.TopLeft:=ADest.TopLeft;
    Result.BottomRight:=FloatPoint(ADest.Left+Sz.cx,ADest.Top+Sz.cy);
end;
end.
