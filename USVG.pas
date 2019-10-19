unit USVG;
// lamdalili
//  SVG based on blender and GR32SVG 
interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,XMLIntf,XMLDoc,UMatrix,IniFiles,USVGStack;
type

  TGradientColor=record
   mLGOffset:Single;
   mLGStopColor:TColor;
   mLGStopOpacity:Single;
  end;
  TArrayGradientColor=array of TGradientColor;
  TStringHashEx=class(TStringHash)
  private
    function GetObj(const AKey: string): Pointer;
  public
    function PutEntry(const AKey:string;Value:Pointer):boolean;
    property Objects[const AKey:string]:Pointer read GetObj;
  end;
  TNodeType=IXmlNode;
  TSVGNode=(snNone,snRect,snLine,snCircle,snEllipse,snPolyLine,snPolygon,snPath,
            snG,snDefs,snUse,snSymbol,snSvg,snStyle,snLinearGradient,
            snRadialGradient,snText);
  PSvgPoint=^TSvgPoint;
  TSvgPoint=record
    X,Y:Double;
  end;
  TSvgPointArray=array of TSvgPoint;
  TSVGToken=(tkNone,tkNumber,tkCmd,tkInvalid);

  TPathSegType=(psMoveTo,psLineTo,psBezierTo,psClose);
  TRectType=record
   X,Y,W,H:Extended;
  end;
  TDimContext=record
    UseClip:boolean;
    ViewPort:TSvgPoint;
    Size:TSvgPoint;
    ClipRect:TRectType;
    Attrs:TStrings;
  end;
  TSVGPathParser=class
  private
    Curr,Prev,Start:TSvgPoint;
    FActive:boolean;
  //  FSize:TRectType;
    procedure GetActiveCurve;
    function ReadPoint(AMove,ARelative:Boolean):TSvgPoint;
    procedure ClosePath;
  protected
    FText: string;
    FPos:integer;
    Flen:integer;
    FCurrToken:TSVGToken;
    FPtsCount:integer;
    FTypesCount:integer;
    procedure SetText(const Value: string);
    procedure InternalParse();
    function Next:TSVGToken;
    function FloatCoord(AMove:boolean):Extended;
    property CurrToken:TSVGToken read FCurrToken;
    procedure LineTo(ARelative:boolean);
    procedure LineHVTo(const AX,AY:Extended;ARelative:boolean);pascal;
    procedure MoveTo(ARelative:boolean);
    procedure CubicTo(ARelative:boolean);
    procedure CubicToSmooth(ARelative:boolean);
    procedure QuadTo(ARelative:boolean);
    procedure QuadToSmooth(ARelative:boolean);
    procedure ArcTo(ARelative:boolean);
    procedure AddTag(ATag:TPathSegType);
    procedure AddPt(const Pt:TSvgPoint;AMoveTo:boolean);
    procedure AddBezier(const P1,P2,P3:TSvgPoint);
  public
    DPts:array of TSvgPoint;
    DTypes:array of TPathSegType;
    procedure Parse(const ACode:string);
  end;

  TSVGLoaderBase=class
  private
    FComp:TComponent;
    procedure ProcessOrg(ANode: TNodeType);
    procedure ParseNodes(ANode: TNodeType);
    procedure ProcessNodeStyle(ANode: TNodeType;ATag:TSVGNode);
    procedure ProcessObj(ANode,AUseCaller: TNodeType);
    procedure Process_Rect(ANode:TNodeType);
    procedure Process_Line(ANode:TNodeType);
    procedure Process_Ellipse(ANode:TNodeType;IsCircle:boolean);
    procedure Process_Poly(ANode:TNodeType;Closed:boolean);
    procedure Process_Path(ANode:TNodeType);
    procedure Process_Use(ANode:TNodeType);
    procedure ParseStyle(Style: TStrings);
    procedure Process_Style(ANode: TNodeType);
    procedure Process_LinearGradient(ANode: TNodeType);
    procedure MergeAttrsNodeStyle(AList:TStringList;ANode: TNodeType);
    function SVGParseColor(const AStr: string): TColor;
    procedure Process_RadialGradient(ANode: TNodeType);
    function SVGGradientColors(ANode: TNodeType): TArrayGradientColor;
    procedure ProcessBox(ANode: TNodeType);
    function ParseMappedLength(ANode: TNodeType; const Attr:string; const ADef: Extended=0): Extended;
    procedure ProcessSize(ANode: TNodeType);
    procedure PreProcess_Use(ANode: TNodeType);
    procedure PreProcess_Symbol(ANode, ACaller: TNodeType);
    procedure Process_Text(ANode: TNodeType);
    procedure Process_Symbol(ANode: TNodeType);
  protected
    FC:TDimContext;
    FFilePath:string;
    FIDs:TStringHashEx;
    FStyles:THashedStringList;
    FStk:TSVGStack;
    FTagsStyle:array[TSVGNode]of string;

    function LengthRef:Extended;
    function ParseMappedPair(ANode:TNodeType;const Attr1,Attr2: string;const ADef1:Extended=0; const ADef2:Extended=0):TSvgPoint;
    procedure Rectangle(const APos,Size,Radius:TSvgPoint);virtual;
    procedure Ellipse(const Center,Radius:TSvgPoint);virtual;
    procedure Poly(const Pts:array of TSvgPoint;AClosed:boolean);virtual;
    procedure Path(const Pts: array of TSvgPoint;const PtTypes: array of TPathSegType);virtual;
    procedure Line(const P1,P2:TSvgPoint);virtual;
    procedure Text(const AStr:string;const APos:TSvgPoint;AFont:TFont;const InlineSize:Extended);virtual;
    procedure BeforeProcessNode(NK:TSVGNode);virtual;
    procedure AfterProcessNode(NK:TSVGNode);virtual;
    procedure BuildLinearGradient(const AName,AUrl:string;const Pt1,Pt2:TSvgPoint;
                                  const Items:TArrayGradientColor;Mat:PMatrix);virtual;
    procedure BuildRadialGradient(const AName,AUrl:string;const Focal,Center:TSvgPoint;Radius:Single;
                                  const Items:TArrayGradientColor;Mat:PMatrix);virtual;
    function GetColorUrl(const AName:string):integer;virtual;
  public
    BGColor:TColor;
    constructor Create();overload;
    destructor Destroy();override;
    procedure LoadFromStream(AStream:TStream);
    procedure LoadFromFile(const AFilename: string);
  end;
  procedure RegisterColorName(const AName:string;AColor:integer);
  function SVGParseValue(const AStr: string;Percent:boolean):Extended;
  function RectType(const X,Y,Width,Height:Extended):TRectType;

implementation
uses Math,StrUtils;
var
 PixelsPerInch:integer;
var
  ColorTable:TStringHashEx;

function RectType(const X,Y,Width,Height:Extended):TRectType;
begin
  Result.X :=X;
  Result.Y :=Y;
  Result.W :=Width;
  Result.H :=Height;
end;

procedure RegisterColorName(const AName:string;AColor:integer);
begin
  ColorTable.Add(AName,AColor );
end;

procedure LoadColorTable();
const ColorsNames:array[0..144]of string=(
    'none', 'aliceblue', 'antiquewhite', 'aqua', 'aquamarine', 'azure', 'beige',
    'bisque', 'black', 'blanchedalmond', 'blue', 'blueviolet', 'brown',
    'burlywood', 'cadetblue', 'chartreuse', 'chocolate', 'coral', 'cornflowerblue',
    'cornsilk', 'crimson', 'cyan', 'darkblue', 'darkcyan', 'darkgoldenrod',
    'darkgray', 'darkgreen', 'darkgrey', 'darkkhaki', 'darkmagenta',
    'darkolivegreen', 'darkorange', 'darkorchid', 'darkred', 'darksalmon',
    'darkseagreen', 'darkslateblue', 'darkslategray', 'darkslategrey',
    'darkturquoise', 'darkviolet', 'deeppink', 'deepskyblue', 'dimgray', 'dimgrey',
    'dodgerblue', 'firebrick', 'floralwhite', 'forestgreen', 'fuchsia',
    'gainsboro', 'ghostwhite', 'gold', 'goldenrod', 'gray', 'grey', 'green',
    'greenyellow', 'honeydew', 'hotpink', 'indianred', 'indigo', 'ivory', 'khaki',
    'lavender', 'lavenderblush', 'lawngreen', 'lemonchiffon', 'lightblue',
    'lightcoral', 'lightcyan', 'lightgoldenrodyellow', 'lightgray', 'lightgreen',
    'lightpink', 'lightsalmon', 'lightseagreen', 'lightskyblue', 'lightslategray',
    'lightslategrey', 'lightsteelblue', 'lightyellow', 'lime', 'limegreen',
    'linen', 'magenta', 'maroon', 'mediumaquamarine', 'mediumblue', 'mediumorchid',
    'mediumpurple', 'mediumseagreen', 'mediumslateblue', 'mediumspringgreen',
    'mediumturquoise', 'mediumvioletred', 'midnightblue', 'mintcream', 'mistyrose',
    'moccasin', 'navajowhite', 'navy', 'oldlace', 'olive', 'olivedrab', 'orange',
    'orangered', 'orchid', 'palegoldenrod', 'palegreen', 'paleturquoise',
    'palevioletred', 'papayawhip', 'peachpuff', 'peru', 'pink', 'plum',
    'powderblue', 'purple', 'red', 'rosybrown', 'royalblue', 'saddlebrown',
    'salmon', 'sandybrown', 'seagreen', 'seashell', 'sienna', 'silver', 'skyblue',
    'slateblue', 'slategray', 'springgreen', 'steelblue', 'tan', 'teal', 'thistle',
    'tomato', 'turquoise', 'violet', 'wheat', 'white', 'whitesmoke', 'yellow',
    'yellowgreen');
ColorsValues:array[0..144]of Cardinal=(
    clNone , $FFF8F0, $D7EBFA, $FFFF00, $D4FF7F,
    $FFFFF0, $DCF5F5, $C4E4FF, $000000, $CDEBFF, $FF0000, $E22B8A,
    $2A2AA5, $87B8DE, $A09E5F, $00FF7F, $1E69D2, $507FFF, $ED9564,
    $DCF8FF, $3C14DC, $FFFF00, $8B0000, $8B8B00, $0B86B8, $A9A9A9,
    $006400, $A9A9A9, $6BB7BD, $8B008B, $2F6B55, $008CFF, $CC3299,
    $00008B, $7A96E9, $8FBC8F, $8B3D48, $4F4F2F, $4F4F2F, $D1CE00,
    $D30094, $9314FF, $FFBF00, $696969, $696969, $FF901E, $2222B2,
    $F0FAFF, $228B22, $FF00FF, $DCDCDC, $FFF8F8, $00D7FF, $20A5DA,
    $808080, $808080, $008000, $2FFFAD, $F0FFF0, $B469FF, $5C5CCD,
    $82004B, $F0FFFF, $8CE6F0, $FAE6E6, $F5F0FF, $00FC7C, $CDFAFF,
    $E6D8AD, $8080F0, $FFFFE0, $D2FAFA, $D3D3D3, $90EE90, $C1B6FF,
    $7AA0FF, $AAB220, $FACE87, $998877, $998877, $DEC4B0, $E0FFFF,
    $00FF00, $32CD32, $E6F0FA, $FF00FF, $000080, $AACD66, $CD0000,
    $D355BA, $DB7093, $71B33C, $EE687B, $9AFA00, $CCD148, $8515C7,
    $701919, $FAFFF5, $E1E4FF, $B5E4FF, $ADDEFF, $800000, $E6F5FD,
    $008080, $238E6B, $00A5FF, $0045FF, $D670DA, $AAE8EE, $98FB98,
    $EEEEAF, $9370DB, $D5EFFF, $B9DAFF, $3F85CD, $CBC0FF, $DDA0DD,
    $E6E0B0, $800080, $0000FF, $8F8FBC, $E16941, $13458B, $7280FA,
    $60A4F4, $578B2E, $EEF5FF, $2D52A0, $C0C0C0, $EBCE87, $CD5A6A,
    $908070, $7FFF00, $B48246, $8CB4D2, $808000, $D8BFD8, $4763FF,
    $D0E040, $EE82EE, $B3DEF5, $FFFFFF, $F5F5F5, $00FFFF, $32CD9A);
var
 I:integer;
begin
  ColorTable:=TStringHashEx.Create(512);
  for I:=0 to 144 do
     ColorTable.Add(ColorsNames[I],ColorsValues[I]);
end;

function SvgPoint(const X,Y:Extended):TSvgPoint;
begin
   Result.X :=X;
   Result.Y :=Y;
end;
function GetAttrText(ANode: TNodeType;const Attr:string;const DV:string):string;
begin
  if ANode.HasAttribute(Attr)then
  begin
    Result:= ANode.GetAttribute(Attr);
  end else
       Result:=DV;
end;

function ParseFloat(const AStr:string;var APos:integer):Extended;
var
  I,P:integer;
  Flags:set of (flPlus,flMinus);
  S:string;
begin
   I:=APos;
   Flags:=[];
   if AStr[I] = '+' then
   begin
      include(Flags,flPlus);
      inc(I);
   end;
   if AStr[I] = '-' then
   begin
      include(Flags,flMinus);
      inc(I);
   end;
   while AStr[I]<=' ' do
        inc(I);
   P:=I;
   while AStr[I] in ['0'..'9'] do
        inc(I);
   if AStr[I] = '.' then
   begin
      inc(I);
      while AStr[I] in ['0'..'9'] do
        inc(I);
   end;
   If AStr[I] in ['E','e'] then
   begin
      inc(I);
      if AStr[I] in ['-','+'] Then
          inc(I);
      while AStr[I] in ['0'..'9'] do
        inc(I);
   end;
   Result:=Strtofloat(Copy(AStr,P,I-P));
   APos:= I;
   case Ord(byte(Flags)) of
      2:Result:=-Result;
      3:Result:=0.0/0.0;
   end;
end;


function SVGParseLength(const AStr: string; const ASize:Extended):Extended;
var
  P:integer;
  Factor:Extended;
  S:string;
begin
   P:=1;
   Result:=ParseFloat(AStr,P);
   if AStr[P]='%' then
   begin
      Result:=Result*ASize/100;
   end else begin
       S:=LowerCase(Copy(AStr,P,2));
       if S='px' then
          Factor:= 1.0
       else if S='in' then
            Factor :=PixelsPerInch
       else if S='mm' then
            Factor := PixelsPerInch / 25.4
       else if S='cm' then
            Factor := PixelsPerInch / 2.54
       else if S='pt' then
            Factor:=  PixelsPerInch / 72.0
       else if S='pc' then
            Factor:=  PixelsPerInch / 6.0
       else if S='em' then
            Factor:= 1.0
       else if S='ex' then
            Factor:= 1.0
       else
          Factor:=0.0;
       if Factor <> 0.0 then
       begin
         Result:=Result*Factor;
       end;
   end;
end;
function SVGParseValue(const AStr: string;Percent:boolean):Extended;
var
  P:integer;
begin
   P:=1;
   Result:=ParseFloat(AStr,P);
   if Percent and (AStr[P]='%') then
   begin
      Result:=Result/100;
   end;
end;
function SVGParseCoordDef(ANode:TNodeType;const Attr: string):Extended;
begin
  if ANode.HasAttribute(Attr)then
  begin
    Result:=SVGParseLength(ANode.GetAttribute(Attr),1);
  end else
       Result:=0;
end;

function SVGInputSplit(const AStr:string):TArrayOfString;
var
  Pts:string;
  I:integer;
begin
    Result:=nil;
    Pts :=StringReplace(AStr,',',' ',[rfReplaceAll]);
    Pts :=StringReplace(Pts,'-',' -',[rfReplaceAll]);
    Pts :=StringReplace(Pts,'e -','e-',[rfReplaceAll]);
    with TStringList.Create do
    try
        DelimitedText:=Pts;
        Setlength(Result,Count);
        for I := 0 to Count-1do
           Result[I]:=Strings[I];
    finally
       Free;
    end;
end;

function ParsePts(const AStr:string):TSvgPointArray;
var
   R:TArrayOfString;
   I,err:integer;
   V:double;
begin
    R :=SVGInputSplit(AStr);
    Setlength(Result,Length(R) div 2);
    for I := 0 to Length(Result) -1do
    begin
       val(R[I*2],V,err);
       Result[I].X:=V;
       val(R[I*2+1],V,err);
       Result[I].Y :=V;
    end;
end;

function SVGTransformTranslate(Params:TStrings):TMatrix;
var
 tx,ty:Extended;
begin
  tx:= StrToFloat(Params[0]);
  ty:=0.0;
  if Params.Count > 1 then
     ty:=StrToFloat(Params[1]);
  Result := IdentityMatrix;
  Result.A[2, 0] := tx;
  Result.A[2, 1] := ty;
end;

function SVGTransformScale(Params:TStrings):TMatrix;
var
 sx,sy:Extended;
begin
  sx:= StrToFloat(Params[0]);
  if Params.Count > 1 then
     sy:=StrToFloat(Params[1])
  else
     sy:=sx;
  Result := IdentityMatrix;
  Result.A[0, 0] := sx;
  Result.A[1, 1] := sy;
end;

function SVGTransformSkewX(Params:TStrings):TMatrix;
var
 ang:Extended;
begin
  ang:= StrToFloat(Params[0])*PI/180;
  Result := IdentityMatrix;
  Result.A[1, 0]  := Tan(ang);
end;

function SVGTransformSkewY(Params:TStrings):TMatrix;
var
 ang:Extended;
begin
  ang:= StrToFloat(Params[0])*pi/180;
  Result := IdentityMatrix;
  Result.A[0, 1]  :=  Tan(ang);
end;

function SVGTransformRotate(Params:TStrings):TMatrix;
var
 ang,cx,cy:Extended;
 tm,rm,t:TMatrix;
begin
  ang:= -StrToFloat(Params[0])*pi/180;
  cx:=0;
  cy:=0;
  if Params.Count >=3 then
  begin
     cx:=StrToFloat(Params[1]);
     cy:=StrToFloat(Params[2]);
  end;
  tm:=TransMx(cx,cy);
  rm:=RotMx(ang);
  t:=MulMx(tm,rm);
  tm:=TransMx(-cx,-cy);
  Result:=MulMx(t,tm);
end;

function SVGTransformMatrix(Params:TStrings):TMatrix;
var
 a,b,c,d,e,f:Extended;
begin
   a:=StrToFloat(Params[0]);
   b:=StrToFloat(Params[1]);
   c:=StrToFloat(Params[2]);
   d:=StrToFloat(Params[3]);
   e:=StrToFloat(Params[4]);
   f:=StrToFloat(Params[5]);
   FillMx(a,b,c,d,e,f,Result);
end;

function SVGParseTransform(const AStr:string):TMatrix;
var
  mPos,mLen:integer;
  procedure SynCheck(ARaise:boolean=true);
  begin
     if ARaise then
        raise Exception.Create('syn transformation');
  end;
  function GetArgs():string;
  var
    d,I,N:integer;
  begin
       Result:='';
       if mPos >= mLen then
          Exit;
       while AStr[mPos]=' ' do
         inc(mPos);
       d:=mPos;
       SynCheck(AStr[mPos]<>'(');
       N:=-1;
       for I:=mPos to mLen do
          if AStr[I]=')' then
          begin
             N:=I;
             break;
          end;
       SynCheck(N=-1);
       mPos:=N;
       Result:=Copy(AStr,d+1,mPos-1-d);
  end;
  function GetTrans():string;
  var
    d:integer;
  begin
       Result:='';
       if mPos >= mLen then
          Exit;
       inc(mPos);
       while AStr[mPos]=' ' do
         inc(mPos);
       d:=mPos;
       while AStr[mPos]in['A'..'Z','a'..'z'] do
         inc(mPos);
       Result:=Copy(AStr,d,mPos-d);
  end;
var
  S,Args:string;
  List:TStringList;
  M:TMatrix;
begin
   mPos:=0;
   mLen:=Length(AStr);
   List:=TStringList.Create;
   try
     Result:=IdentityMatrix;
     repeat
        Args:='';
        S:=LowerCase(GetTrans());
        if S<>'' then
        begin
           Args:= GetArgs();
           Args :=StringReplace(Args,',',' ',[rfReplaceAll]);
           Args :=StringReplace(Args,'-',' -',[rfReplaceAll]);
           Args :=StringReplace(Args,'e -','e-',[rfReplaceAll]);
           List.DelimitedText:=Args;
           SynCheck(List.Count=0);
           if S='translate' then
              M:= SVGTransformTranslate(List)
           else if S='rotate' then
              M:= SVGTransformRotate(List)
           else if S='scale' then
              M:= SVGTransformScale(List)
           else if S='skewx' then
              M:= SVGTransformSkewX(List)
           else if S='skewy' then
              M:= SVGTransformSkewY(List)
           else if S='matrix' then
              M:= SVGTransformMatrix(List)
           else
              SynCheck();
           Result:= MulMx(Result,M);
        end;
     until mPos >= mLen;
   finally
     List.Free;
   end;
end;

function SVGParseStyle(Dest:TStrings;const AStyle:string):Integer;
var
 I,L,S,sPos:integer;
 nKey,Value,t:string;
begin
  Result:=Dest.Count;
  L:=Length(AStyle);
  I:=1;
  repeat
     S:=I;
     while I <= L do
     begin
      if AStyle[I]=';' then
         break;
      inc(I);
     end;
     t:=LowerCase(Copy(AStyle,S,I-S));
     sPos:=Pos(':',t);
     if sPos <> 0 then
     begin
        nKey :=Trim(Copy(t,1,sPos-1));
        Value:=Trim(Copy(t,sPos+1,MAXINT));
        Dest.Values[nKey]:=Value;
     end;
     Inc(I);
  until I > L;
  Result:=Dest.Count- Result;
end;

function SVGSplit(const AStr:string;AChar:Char):TArrayOfString;
var
   I,S,L:integer;
   t:string;
begin
    Result:=nil;
    with TStringList.Create do
    try
        L:=Length(AStr);
        I:=1;
        repeat
           S:=I;
           while I <= L do
           begin
            if AStr[I]=AChar then
               break;
            inc(I);
           end;
           t:=Copy(AStr,S,I-S);
           Add(t);
           Inc(I);
        until I > L;
        Setlength(Result,Count);
        for I := 0 to Count-1do
           Result[I]:=Strings[I];
    finally
       Free;
    end;
end;

function SVGParseStrokeDashArray(const S: string):TArrayOfSingle;
var
  I,L: Integer;
  Ds:TArrayOfString;
begin
  Result:=nil;
  if S='none' then
     Exit;
  Ds:=SVGInputSplit(S);
  L:=Length(Ds);
  if L=0 then
     Exit;
  if L mod 2 = 1 then
  begin
    SetLength(Result,L*2);
    for I := 0 to L - 1 do
      Result[I]:=StrToFloatDef(Ds[I],0);
    for I := 0 to L - 1 do
      Result[L+I]:=StrToFloatDef(Ds[I],0);
  end else begin
    SetLength(Result,L);
    for I := 0 to L - 1 do
      Result[I]:=StrToFloatDef(Ds[I],0);
  end;
end;

function HashOf(const AStr:string):integer;
var
 I:integer;
begin
  Result := 0;
  for I := 1 to Length(AStr) do
    Result := (Result shl 3) xor Result xor Ord(AStr[I]);
end;

function GetTagType(const AName:string):TSVGNode;
var
 hash:Cardinal;
 nName:string;
begin
    Result:=snNone;
    if AName='' then
      Exit;
    nName:=Lowercase(AName);
    if Sametext(Copy(nName,1,4),'svg:') then
       nName:=Copy(nName,5,MAXINT);

    hash :=Cardinal(HashOf(nName));
    case hash of
      $0000E46D: Result:=snPath;
      $0000D95E: Result:=snLine;
      $0031C3BA: Result:=snCircle;
      $01A49EDA: Result:=snEllipse;
      $0000E148: Result:=snRect;
      $0E729E74: Result:=snPolyline;
      $01F05A24: Result:=snPolygon;
      $0000C844: Result:=snDefs;
      $00000067: Result:=snG;
      $0039FA4E: Result:=snSymbol;
      $00001EBB: Result:=snUse;
      $00001F12: Result:=snSvg;
      $0007DBF7: Result:=snStyle;
      $C980978B: Result:=snLinearGradient;
      $E78EE2A5: Result:=snRadialGradient;
      $0000EC3D: Result:=snText;
    end;
end;
{ TSVGLoader }

procedure TSVGLoaderBase.LoadFromFile(const AFilename: string);
var
 FS:TFilestream;
begin
  FFilePath:=ExtractFilePath(AFilename);
  FS:=TFilestream.Create(AFilename,fmOpenRead);
  try
     LoadFromstream(FS);
  finally
     FFilePath:='';
     FS.Free;
  end;
end;

constructor TSVGLoaderBase.Create;
begin
  FIDs:=TStringHashEx.Create;
  FStk:=TSVGStack.Create;
  FStyles:=THashedStringList.Create;
  BGColor:=clWhite;
end;

destructor TSVGLoaderBase.Destroy;
begin
  FStyles.Free;// to complete  clear obj
  FStk.Free;
  FIDs.Free;
  inherited;
end;
function TSVGLoaderBase.ParseMappedPair(ANode: TNodeType; const Attr1,
  Attr2: string; const ADef1, ADef2: Extended): TSvgPoint;
begin
    if ANode.HasAttribute(Attr1)then
      Result.X:=SVGParseLength(ANode.GetAttribute(Attr1),FC.ViewPort.x)
    else
      Result.X:=ADef1;
    if ANode.HasAttribute(Attr2)then
      Result.Y:=SVGParseLength(ANode.GetAttribute(Attr2),FC.ViewPort.y)
    else
      Result.Y:=ADef2;
end;

function TSVGLoaderBase.ParseMappedLength(ANode: TNodeType; const Attr:string;const ADef: Extended):Extended;
begin
  if ANode.HasAttribute(Attr)then
    Result:=SVGParseLength(ANode.GetAttribute(Attr),LengthRef)
  else
    Result:= ADef
end;

procedure TSVGLoaderBase.ProcessBox(ANode: TNodeType);
var
  M:TArrayOfString;
  vx,vy,vw,vh:Extended;
  tx,ty,scale:Extended;
  Rc:TSvgPoint;
  Mx:TMatrix;
  cc,vv:Extended;
  D:TSvgPoint;
begin
    if ANode.HasAttribute('viewBox')then
    begin
       M:=SVGInputSplit(ANode.GetAttribute('viewBox'));
       if Length(M)<> 4 then
         Exit;
       vx :=SVGParseLength(M[0],FC.ViewPort.X);
       vy :=SVGParseLength(M[1],FC.ViewPort.Y);        // complet testing
       vw :=SVGParseLength(M[2],FC.ViewPort.X);
       vh :=SVGParseLength(M[3],FC.ViewPort.Y);
       scale:=min((FC.ViewPort.X) /vw, (FC.ViewPort.Y)/vh);

       tx := (FC.ViewPort.X - vw*scale) * 0.5;
       ty := (FC.ViewPort.Y - vh*scale) * 0.5;
       FC.ClipRect.X := vx-tx/scale;
       FC.ClipRect.Y := vy-ty/scale;
       FC.ClipRect.W := vx+(FC.ViewPort.x-tx)/scale;
       FC.ClipRect.H := vy+(FC.ViewPort.y-ty)/scale;
       FillMx(Scale,0,0,Scale,tx-vx*scale,ty-vy*scale ,Mx);
       FStk.Matrix :=MulMx(FStk.Matrix,Mx);
       FC.ViewPort:=SvgPoint(vw,vh);
    end;
end;

procedure TSVGLoaderBase.ProcessSize(ANode: TNodeType);
begin
  with ANode do
   if HasAttribute('width') or HasAttribute('height') then
    begin
     FC.ViewPort:=ParseMappedPair(ANode,'width','height',FC.ViewPort.x,FC.ViewPort.y);
    end;
  FC.Size:=FC.ViewPort;
  FC.ClipRect:=RectType(0,0,FC.ViewPort.X,FC.ViewPort.Y);
end;

procedure TSVGLoaderBase.ProcessOrg(ANode: TNodeType);
var
  Ps:TSvgPoint;
begin
   Ps:=ParseMappedPair(ANode,'x','y');
   if (Ps.X <> 0) or (Ps.Y <> 0) then
      FStk.Matrix := MulMx(FStk.Matrix,TransMx(Ps.x,Ps.y));
end;

procedure TSVGLoaderBase.PreProcess_Use(ANode: TNodeType);
begin
   ProcessOrg(ANode);
   ProcessSize(ANode);
end;

procedure TSVGLoaderBase.PreProcess_Symbol(ANode,ACaller: TNodeType);
begin
   ProcessOrg(ANode);
   ProcessSize(ANode);
   ProcessBox(ANode);
   FC.UseClip:= True;
end;
procedure TSVGLoaderBase.Process_Symbol(ANode: TNodeType);
var
 I:integer;
begin
   if ANode.HasChildNodes then
     for I := 0 to ANode.ChildNodes.Count - 1 do
         ProcessObj(ANode.ChildNodes.Nodes[I],nil);
end;
procedure TSVGLoaderBase.LoadFromStream(AStream: TStream);
var
  Doc:TXMLDocument;
  L:IXMLDocument;
  N:IXmlNode;

begin
  FreeAndNil(Fcomp);
  Fcomp:=TComponent.Create(nil);
  Doc:=TXMLDocument.Create(Fcomp);//  as IXMLDocument)
  L:= Doc as IXMLDocument;
  L.LoadFromStream(Astream);
  N:=Doc.DocumentElement;
 // SetSize(800,800);
  FC.ViewPort:=SvgPoint(800,800);
  FC.Size:=FC.ViewPort;
  FStk.BeginCapture();
  ParseNodes(n);
  FStk.Matrix:=IdentityMatrix;
  FStk.FontFamily:='Default';
  FStk.FontSize:=14;
  FStk.PenWidth:=1.0;
  FStk.PenColor:=clNone;
  FStk.FillColor:=clBlack;
  FStk.FillOpacity:=1.0;
  FStk.PenOpacity:=1.0;
  FStk.MiterLimit :=4.0;
  FStk.Display:=svgInline;
  FStk.Visibility:=svgVisible;
  FStk.FillMode :=svgNonZero;   // default svg
  ProcessObj(n,nil);
  FStk.EndCapture();
end;

function TSVGLoaderBase.SVGParseColor(const AStr:string):TColor;
var
  t,c,s,url:string;
  RParent,Sep1,Sep2:integer;
begin
   t:=Trim(AStr);
   Result:=ColorTable.ValueOf(t);
   if Result <> -1 then
      Exit;
   Result:=clBlack;
   if t='' then
      Exit;
   if t[1]='#' then
   begin
     C:=Copy(t,2,MAXINT);
     case length(C) of
       3:t:=c[3]+ c[3]+ c[2]+ c[2]+ c[1]+ c[1];
       6:t:=c[5]+ c[6]+ c[3]+ c[4]+ c[1]+ c[2];
     else
        Exit;
     end;
     Result:=StrToIntDef('$'+t ,clBlack);
   end else begin
     s:=Copy(t,1,4);
     if s='url('then
     begin
       RParent:=Pos(')',t);
       if RParent = 0 then
          Exit;
       url:=Copy(t,5,RParent-5);
       Result:=GetColorUrl(url);
     end else if s='rgb('then
     begin
       RParent:=Pos(')',t);
       if RParent = 0 then
          Exit;
       with TStringList.Create do
       try
          Delimiter:=',';
          DelimitedText:=Copy(t,5,RParent-5);
          if Count <> 3 then
             Exit;
          Result:=rgb(Trunc(SVGParseValue(Strings[0],False)),
                      Trunc(SVGParseValue(Strings[1],False)),
                      Trunc(SVGParseValue(Strings[2],false)));

       finally
          Free;
       end;
     end;
   end;
end;

function TSVGLoaderBase.SVGGradientColors(ANode:TNodeType):TArrayGradientColor;
var
 I:integer;
 N:TNodeType;
 List:THashedStringList;
 Value,Id:string;
    function ReadKey(const AName:string;var AOut:string):boolean;
    begin
       AOut:= List.Values[AName];
       Result:= AOut <> '';
    end;
begin
   Result:=nil;
   if not ANode.HasChildNodes then
      Exit;
   Setlength(Result,ANode.ChildNodes.Count);
   for I:= 0 to ANode.ChildNodes.Count-1 do
     with Result[I] do
     begin
       N:=ANode.ChildNodes[I];
       if N.NodeName <> 'stop' then
          continue;
       List:= THashedStringList.Create;
       try
         MergeAttrsNodeStyle(List,N);
         if ReadKey('offset',Value) then
            mLGOffset:=SVGParseValue(Value,True);
         if ReadKey('stop-color',Value) then
            mLGStopColor:=SVGParseColor(Value);
         if ReadKey('stop-opacity',Value) then
            mLGStopOpacity:=SVGParseValue(Value,True)
         else
            mLGStopOpacity:=1
       finally
          List.Free;
       end;
     end;
end;

procedure TSVGLoaderBase.Process_LinearGradient(ANode: TNodeType);
var
 Id,ColorLink:string;
 GRColors:TArrayGradientColor;
 Pt1,Pt2:TSvgPoint;
 M:TMatrix;
 P:PMatrix;
begin
   if not ANode.HasAttribute('id') then
      Exit;
   GRColors:=SVGGradientColors(ANode);
   Id:=ANode.GetAttribute('id');           //unmapped values
   Pt1.X := SVGParseCoordDef(ANode,'x1');  // be carefull no meaning
   Pt1.Y := SVGParseCoordDef(ANode,'y1');  // for "ViewPort" at parse time
   Pt2.X := SVGParseCoordDef(ANode,'x2');  // for percent unit
   Pt2.Y := SVGParseCoordDef(ANode,'y2');
   P:=nil;
   if ANode.HasAttribute('gradientTransform')then
   begin
      M:=SVGParseTransform(ANode.GetAttribute('gradientTransform'));
      P:=@M;
   end;
   ColorLink:= GetAttrText(ANode,'xlink:href','');
   BuildLinearGradient('#'+Id,ColorLink,Pt1,Pt2,GRColors,P);
end;

procedure TSVGLoaderBase.Process_RadialGradient(ANode: TNodeType);
var
 N:TNodeType;
 GRColors:TArrayGradientColor;
 Id,ColorLink:string;
 F,C:TSvgPoint;
 r:Single;
 M:TMatrix;
 P:PMatrix;
begin
   if not ANode.HasAttribute('id') then
      Exit;

   GRColors:=SVGGradientColors(ANode);
   Id:=ANode.GetAttribute('id');         //unmapped value
   F.X := SVGParseCoordDef(ANode,'fx');  // be carefull no meaning
   F.Y := SVGParseCoordDef(ANode,'fy');  // for "ViewPort" at parse time
   C.X := SVGParseCoordDef(ANode,'cx');  // for percent unit
   C.Y := SVGParseCoordDef(ANode,'cy');
   r   := SVGParseCoordDef(ANode,'r' );
   P:=nil;
   if ANode.HasAttribute('gradientTransform')then
   begin
      M:=SVGParseTransform(ANode.GetAttribute('gradientTransform'));
      P:=@M;
   end;
   ColorLink:= GetAttrText(ANode,'xlink:href','');
  BuildRadialGradient('#'+Id,ColorLink,F,C,r,GRColors,P);
end;

procedure TSVGLoaderBase.Process_Style(ANode: TNodeType);
var
 B1,B2:integer;
 nName,Values,S,t:string;
 Tag:TSVGNode;
begin
    S:=VarToStr(ANode.NodeValue);
    B2:=1;
    repeat
        B1:=PosEx('{',S,B2);
        if B1 = 0 then
           Exit;
        nName :=Trim(Copy(S,B2,B1-B2));
        B2:=PosEx('}',S,B1);
        if B2=0 then
           Exit;
        Values:=Trim(Copy(S,B1+1,B2-B1-1));
        Inc(B2);
        Tag:=GetTagtype(nName);
        if (Values='')or (Tag in [snDefs,snSvg])then
           continue;
        if (Tag <> snNone)then
        begin
           t:=FTagsStyle[Tag];
           if t='' then
              FTagsStyle[Tag]:=Values
           else
              FTagsStyle[Tag]:=t+';'+Values
        end else begin
           t:=FStyles.Values[nName];
           if t='' then
              FStyles.Values[nName]:=Values
           else
              FStyles.Values[nName]:=t+';'+Values
        end;
    until False;
end;

procedure TSVGLoaderBase.ParseNodes(ANode: TNodeType);
var
 N:TNodeType;
 I:integer;
 Tag: TSVGNode;
 S:string;
begin
  if ANode.HasChildNodes then
   for I := 0 to ANode.ChildNodes.Count - 1 do
   begin
       N:=ANode.ChildNodes.Nodes[I];
       if N.NodeType = ntElement then
       begin
          Tag:=GetTagtype(N.NodeName);
          if Tag=snNone then
             continue;
          S:='';
          if N.HasAttribute('id')then
             S:= '#'+N.GetAttribute('id');
          if N.HasAttribute('class')then
             S:= N.GetAttribute('class');
          if S <> '' then
             FIds.PutEntry(S,Pointer(N));
          case Tag of
            snStyle: Process_Style(N);
   snLinearGradient: Process_LinearGradient(N);
   snRadialGradient: Process_RadialGradient(N);
            snG,snDefs,snSymbol: ParseNodes(N);
          end;
       end;
   end;
end;

procedure TSVGLoaderBase.ProcessObj(ANode,AUseCaller: TNodeType);
label _End;
var
 I:integer;
 Tag: TSVGNode;
 OldContext:TDimContext;
begin
   if ANode.NodeType = ntElement then
   begin
      Tag:=GetTagtype(ANode.NodeName);
      if Tag=snNone then
         Exit;
      OldContext:=FC;
      FStk.BeginCapture();
      if ANode.HasAttribute('transform') then
         FStk.Matrix := MulMx(FStk.Matrix,SVGParseTransform(ANode.GetAttribute('transform')));
      case Tag of //preprocess
          snSvg:begin
                ProcessSize(ANode);
                ProcessBox(ANode);
          end;
       snSymbol:PreProcess_Symbol(ANode,AUseCaller);
          snUse:PreProcess_Use(ANode);
      end;
      with FC.ViewPort do
        if (x = 0)or (y = 0) then
           goto _End;
      ProcessNodeStyle(ANode,Tag);
      BeforeProcessNode(Tag);
      case Tag of
          snPath: Process_Path(ANode);
          snRect: Process_Rect(ANode);
       snEllipse: Process_Ellipse(ANode,False);
        snCircle: Process_Ellipse(ANode,True);
          snLine: Process_Line(ANode);
       snPolygon: Process_Poly(ANode,True);
      snPolyLine: Process_Poly(ANode,False);
           snUse: Process_Use(ANode);
          snText: Process_Text(ANode);
       snSymbol : Process_Symbol(ANode);
         snG,snSvg:begin
               if ANode.HasChildNodes then
                 for I := 0 to ANode.ChildNodes.Count - 1 do
                     ProcessObj(ANode.ChildNodes.Nodes[I],nil);
             end;
           {snDefs:  no instancing}
      end;
    AfterProcessNode(Tag);
   _End: FStk.EndCapture();
    FreeAndNil(FC.Attrs);//created in ProcessNodeStyle
    FC:=OldContext;
   end;
end;

procedure TSVGLoaderBase.Process_Ellipse(ANode: TNodeType; IsCircle: boolean);
var
  c,r:TSvgPoint;
begin
  c := ParseMappedPair(ANode,'cx','cy');
  if isCircle then
  begin
    r.X:=ParseMappedLength(ANode,'r');
    r.Y := r.X;
  end else begin
    r := ParseMappedPair(ANode,'rx','ry');
  end;
  if (r.X=0)or(r.Y=0) then    // warning
     Exit;
  Ellipse(C,R);
end;

procedure TSVGLoaderBase.Process_Line(ANode: TNodeType);
var
  P1,P2:TSvgPoint;
begin
  P1 := ParseMappedPair(ANode,'x1','y1');
  P2 := ParseMappedPair(ANode,'x2','y2');
  Line(P1,P2);
end;

procedure TSVGLoaderBase.Process_Path(ANode: TNodeType);
begin
  with TSVGPathParser.Create()do
  try
       //FSize:= FStk.ViewPort;
       Parse(GetAttrText(ANode,'d',''));
       Path(DPts,DTypes);
  finally
     Free;
  end;
end;

procedure TSVGLoaderBase.Process_Poly(ANode: TNodeType; Closed: boolean);
begin
  Poly(ParsePts(ANode.getAttribute('points')),Closed);
end;

procedure TSVGLoaderBase.Process_Rect(ANode: TNodeType);
var
  Ps,Sz,Rd:TSvgPoint;
begin
  Ps:=ParseMappedPair(ANode,'x','y');
  Sz:=ParseMappedPair(ANode,'width','height');
  Rd:=ParseMappedPair(ANode,'rx','ry',-1,-1);
  if (Rd.X<>-1) and (Rd.Y<>-1) then
  begin
    Rd.X:=min(Rd.X,Sz.X/2);
    Rd.Y:=min(Rd.Y,Sz.Y/2);
  end else if (Rd.X<>-1) then
  begin
    Rd.X:=min(Rd.X,Sz.X/2);
    Rd.Y:=min(Rd.X,Sz.Y/2);
  end else if (Rd.Y<>-1) then
  begin
    Rd.X:=min(Rd.Y,Sz.X/2);
    Rd.Y:=min(Rd.Y,Sz.Y/2);
  end else begin
    Rd.X:=0;
    Rd.Y:=0;
  end ;
  Rectangle(Ps,Sz,Rd);
end;

procedure TSVGLoaderBase.Process_Use(ANode: TNodeType);
var
 G:TNodeType;
 S:string;
begin
  if ANode.HasAttribute('xlink:href')then
  begin
    S:= ANode.GetAttribute('xlink:href');
    G:=TNodeType(FIds.Objects[S]);
    if G <>nil then
       ProcessObj(G,ANode);
  end;
end;
function GetFullText(ANode:TNodeType):string;
var
 I:integer;
 S:string;
begin
   Result:='';
   if ANode.NodeType = ntElement then
   begin
      if ANode.HasChildNodes  then
       for I := 0 to ANode.ChildNodes.Count - 1 do
       begin
           S:=GetFullText(ANode.ChildNodes[I]);
           if Result=''  then
              Result:=S
           else if S <>'' then
             Result:=Result+' '+S;
       end;
   end else if ANode.NodeType = ntText then
           Result:=ANode.Text;
end;
procedure TSVGLoaderBase.Process_Text(ANode: TNodeType);
var
 InlineSz:Extended;
 S:string;
 Pz:TSvgPoint;
 Font:TFont;
 Fs:TFontStyles;
 Avlength:Double;
begin
  S:=GetFullText(ANode);
  if S='' then
     Exit;
 Pz:=ParseMappedPair(ANode,'x','y');//only first X Y
 Avlength:=fc.ViewPort.X-Pz.X;
 InlineSz:= ParseMappedLength(ANode,'inline-size',Avlength);
 Font:=TFont.Create;
 try
   Font.Name:=FStk.FontFamily;
   Fs:=[];
   if FStk.FontDecoration=svgUnderline then
      include(Fs,fsUnderline);
   if FStk.FontWeight=svgBold then
      include(Fs,fsBold);
   if FStk.FontStyle=svgItalic then
      include(Fs,fsItalic);

   Font.Style:=Fs;
   Font.Height:= -FStk.FontSize;
   Text(S,Pz,Font,InlineSz);
 finally
    Font.Free;
 end;
end;

procedure TSVGLoaderBase.Rectangle(const APos,Size,Radius:TSvgPoint);
begin
end;

procedure TSVGLoaderBase.Ellipse(const Center,Radius:TSvgPoint);
begin
end;

procedure TSVGLoaderBase.Path(const Pts: array of TSvgPoint;const PtTypes:array of TPathSegType);
begin
end;

procedure TSVGLoaderBase.Poly(const Pts: array of TSvgPoint;AClosed:boolean);
begin
end;

procedure TSVGLoaderBase.Text(const AStr: string; const APos: TSvgPoint;
  AFont: TFont; const InlineSize: Extended);
begin
end;

function TSVGLoaderBase.LengthRef: Extended;
begin
  with FC.ViewPort do
    Result:=Hypot(x,y)/Sqrt(2);
end;

procedure TSVGLoaderBase.Line(const P1,P2:TSvgPoint);
begin
end;

procedure TSVGLoaderBase.AfterProcessNode(NK: TSVGNode);
begin
end;

procedure TSVGLoaderBase.BeforeProcessNode(NK: TSVGNode);
begin
end;
{ TStringHashEx }

function TStringHashEx.PutEntry(const AKey: string; Value: Pointer):boolean;
var
 P:PPHashItem;
 Bucket: PHashItem;
begin
  P:=Find(AKey);
  Result:=P^= nil;
  if Result then
  begin
      New(Bucket);
      Bucket^.Key := AKey;
      Bucket^.Value := Integer(Value);
      Bucket^.Next := nil;
      P^:=Bucket;
  end;
end;

function TStringHashEx.GetObj(const AKey: string): Pointer;
var
 v:integer;
begin
  v:=ValueOf(AKey);
  if v=-1 then
     Result:=nil
  else
     Result:=Pointer(v);
end;


{ TSVGPathParser }

procedure TSVGPathParser.SetText(const Value: string);
begin
  FText := Value;
  Flen:=Length(FText);
  FPos:=0;
  FCurrToken:= tkNone;
end;

function TSVGPathParser.Next:TSVGToken;
const
    NumTok: set of char =  ['+','-','.','0','1','2','3','4','5','6','7','8','9'];
    spaces : set of char = [#1..' ',','];
    commands: set of char =['m', 'l', 'h', 'v', 'c', 's', 'q', 't', 'a', 'z',
                            'M', 'L', 'H', 'V', 'C', 'S', 'Q', 'T', 'A', 'Z'];
var
  c:Char;
begin
  Result:=tkNone;
  if FPos < FLen then
   begin
      repeat
         inc(FPos);
         c:=FText[FPos];
      until not (c in spaces) ;
      c := FText[FPos];
      if c in NumTok then
          Result:=tkNumber
      else if c in commands then
         Result:=tkCmd
      else
          Result:=tkInvalid;
  end;
  FCurrToken:=Result;
end;

function TSVGPathParser.ReadPoint(AMove,ARelative:Boolean):TSvgPoint;
begin
   Result.X:=FloatCoord(AMove);
   Result.Y:=FloatCoord(True);
   if ARelative then
   begin
      Result.X:= Result.X+Curr.X;
      Result.Y:= Result.Y+Curr.Y;
   end;
end;
function TSVGPathParser.FloatCoord(AMove:boolean): Extended;
begin
   if AMove then
      Next;
   Result:=ParseFloat(FText,FPos);
   Dec(FPos);
end;

procedure TSVGPathParser.InternalParse;
var
  C:Char;
  Relative:boolean;
begin
   Next;
   while CurrToken=tkCmd do
   begin
      C:= FText[FPos];
      Relative:=C in['m', 'l', 'h', 'v', 'c', 's', 'q', 't', 'a', 'z'];
      case C of
        'M','m': MoveTo(Relative);
        'L','l': while Next=tkNumber do LineTo(Relative);
        'C','c': while Next=tkNumber do CubicTo(Relative);
        'A','a': while Next=tkNumber do ArcTo(Relative);
        'Z','z': ClosePath();
        'S','s': while Next=tkNumber do CubicToSmooth(Relative);
        'Q','q': while Next=tkNumber do QuadTo(Relative);
        'T','t': while Next=tkNumber do QuadToSmooth(Relative);
            'H': while Next=tkNumber do LineHVTo(FloatCoord(False),Curr.Y,False);
            'h': while Next=tkNumber do LineHVTo(FloatCoord(False),0,True);
            'V': while Next=tkNumber do LineHVTo(Curr.X,FloatCoord(False),False);
            'v': while Next=tkNumber do LineHVTo(0,FloatCoord(False),True);
         else
             break;
      end;
  end;
end;

procedure TSVGPathParser.Parse(const ACode:string);
begin
   SetText(ACode);
   InternalParse();
   Setlength(DPts,FPtsCount); //pack
   Setlength(DTypes,FTypesCount);               //pack
end;

procedure TSVGPathParser. GetActiveCurve;
begin
   if not FActive then
   begin
      FActive:=True;
      Curr.X:=0.0;
      Curr.Y:=0.0;
      Start:=Curr;
      Prev := Curr;
      AddPt(Curr,True);
   end;
end;

procedure TSVGPathParser.ClosePath;
begin
   if not FActive then
     raise Exception.Create('no active curve');
  // if Curr<> Start then     to implemented
  // AddPt(Start,False);    // veref
   AddTag(psClose);
   Curr:= Start;
   Prev:= Curr;
   FActive := False;
   Next;
end;

procedure TSVGPathParser.ArcTo(ARelative: boolean);
var
  n_segs,I:integer;
  x0,y0,x1,y1,d,sq,sf,x2,y2,x3,y3,t:Extended;
  xc,yc,ang_0,ang_1,ang_arc,ang0,ang1,ang_demi:Extended;
  P1,P2,P3,r,_t0,_t1:TSvgPoint;
  ang,_sin,_cos:Extended;
  fa,fs:boolean;
begin
    GetActiveCurve();
    P1:=ReadPoint(False,False);
    r:=SvgPoint( abs(P1.X),abs(P1.Y));
    ang:=FloatCoord(True)*Pi/180;
    fa:=FloatCoord(True)=1.0;
    fs:=FloatCoord(True)=1.0;
    P1:=ReadPoint(True,ARelative);
    if (r.X = 0) or (r.Y = 0) then
    begin
        AddPt(P1,False);
        Exit;
    end;
    _sin:=sin(ang);
    _cos:=cos(ang);
    _t0.X := (_cos * (Curr.X - P1.X) + _sin * (Curr.Y - P1.Y)) * 0.5;
    _t0.Y := (_cos * (Curr.Y - P1.Y) - _sin * (Curr.X - P1.X)) * 0.5;
    d := Sqr(_t0.X/r.X) + Sqr(_t0.Y/r.Y);
    if d > 1.0 then
       r:=SvgPoint(r.X*sqrt(d),r.Y*sqrt(d));

    _t0 := SvgPoint(_cos / r.X,_cos / r.Y);
    _t1 := SvgPoint(_sin / r.X,_sin / r.Y);
    x0 :=  _t0.X * Curr.X + _t1.X * Curr.Y;
    y0 := -_t1.Y * Curr.X + _t0.Y * Curr.Y;
    x1 :=  _t0.X * P1.X  + _t1.X * P1.Y;
    y1 := -_t1.Y * P1.X  + _t0.Y * P1.Y;
    d := Sqr(x1 - x0) + Sqr(y1 - y0);
    if d > 0.0 then
        sq := 1.0 / d - 0.25
    else
        sq := -0.25;

    if sq < 0.0 then
        sq := 0.0;

    sf :=sqrt(sq);
    if fs = fa then
        sf := -sf;
    xc := 0.5 * (x0 + x1) - sf * (y1 - y0);
    yc := 0.5 * (y0 + y1) + sf * (x1 - x0);
    ang_0 := arctan2(y0 - yc, x0 - xc);
    ang_1 := arctan2(y1 - yc, x1 - xc);
    ang_arc := ang_1 - ang_0;

    if (ang_arc < 0.0) and fs then
        ang_arc :=ang_arc+ 2.0 * pi
    else if (ang_arc > 0.0) and not fs then
        ang_arc :=ang_arc- 2.0 * pi;
    n_segs := ceil(abs(ang_arc * 2.0 / (pi * 0.5 + 0.001)));
    for I:=0 to n_segs-1 do
    begin
        ang0 := ang_0 + i * ang_arc / n_segs;
        ang1 := ang_0 + (i + 1) * ang_arc / n_segs;
        ang_demi := 0.25 * (ang1 - ang0);
        t := 2.66666 * sin(ang_demi) * sin(ang_demi) / sin(ang_demi * 2.0);
        x1 := xc + cos(ang0) - t * sin(ang0);
        y1 := yc + sin(ang0) + t * cos(ang0);
        x2 := xc + cos(ang1);
        y2 := yc + sin(ang1);
        x3 := x2 + t * sin(ang1);
        y3 := y2 - t * cos(ang1);
        P1.X:= _cos * r.X * x1 + -_sin * r.Y * y1;
        P1.Y:= _sin * r.X * x1 +  _cos * r.Y * y1;
        P2.X:= _cos * r.X * x3 + -_sin * r.Y * y3;
        P2.Y:= _sin * r.X * x3 +  _cos * r.Y * y3;
        P3.X:= _cos * r.X * x2 + -_sin * r.Y * y2;
        P3.Y:= _sin * r.X * x2 +  _cos * r.Y * y2;
        AddBezier(P1,P2,P3);
        Curr:=P3;
   end;
   Prev:=Curr;
end;

procedure TSVGPathParser.CubicTo(ARelative: boolean);
var
 P1:TSvgPoint;
begin
   GetActiveCurve();
   P1:=ReadPoint(False,ARelative);
   Prev:=ReadPoint(True,ARelative);
   Curr:=ReadPoint(True,ARelative);
   AddBezier(P1,Prev,Curr);
end;

procedure TSVGPathParser.CubicToSmooth(ARelative: boolean);
var
 P1:TSvgPoint;
begin
   GetActiveCurve();
   with Curr do
   begin
     P1.X:=X*2-Prev.X;
     P1.Y:=Y*2-Prev.Y;
   end;
   Prev:=ReadPoint(False,ARelative);
   Curr:=ReadPoint(True,ARelative);
   AddBezier(P1,Prev,Curr);
end;

procedure TSVGPathParser.MoveTo(ARelative: boolean);
begin
   FActive:=True;
   Curr:=ReadPoint(True,ARelative);
   Prev:=Curr;
   Start:=Curr;
   AddPt(Curr,True);
   while Next=tkNumber do
     LineTo(ARelative);
end;

procedure TSVGPathParser.LineTo(ARelative:boolean);
begin
   GetActiveCurve();
   Curr:=ReadPoint(False,ARelative);
   Prev:=Curr;
   AddPt(Curr,False);
end;

procedure TSVGPathParser.LineHVTo(const AX,AY:Extended;ARelative: boolean);
begin
  GetActiveCurve();
  if ARelative then
  begin
    Curr.X := Curr.X + AX;
    Curr.Y := Curr.Y + AY;
  end else begin
    Curr.X := AX;
    Curr.Y := AY;
  end;
  Prev:=Curr;
  AddPt(Curr,False);
end;

procedure QuadToCubic(const P1,P2,P3:TSvgPoint; var Pt1,Pt2: TSvgPoint);
begin
   Pt1.X :=(P1.X + 2* P2.X) / 3;
   Pt1.Y :=(P1.Y + 2* P2.Y) / 3;
   Pt2.X :=(P3.X + 2* P2.X) / 3;
   Pt2.Y :=(P3.Y + 2* P2.Y) / 3;
end;

procedure TSVGPathParser.QuadTo(ARelative: boolean);
var
  P1,P2,Pt1:TSvgPoint;
begin
   GetActiveCurve();
   P1 := Curr;
   P2 := ReadPoint(False,ARelative);
   Curr:= ReadPoint(True,ARelative);
   QuadToCubic(P1,P2,Curr,Pt1,Prev);
   AddBezier(Pt1,Prev,Curr);
end;

procedure TSVGPathParser.QuadToSmooth(ARelative: boolean);
var
  P1,P2,Pt1:TSvgPoint;
begin
   GetActiveCurve();
   P1 := Curr;
   with Curr do
   begin
     P2.X :=X*2-Prev.X;
     P2.Y :=Y*2-Prev.Y;
   end;
   Curr:=ReadPoint(False,ARelative);
   QuadToCubic(P1,P2,Curr,Pt1,Prev);
   AddBezier(Pt1,Prev,Curr);
end;

procedure TSVGPathParser.AddTag(ATag: TPathSegType);
var
 Cap:integer;
begin
  Cap:=Length(DTypes);
  if Cap = FTypesCount then
     Setlength(DTypes,Cap+64);
  DTypes[FTypesCount]:=ATag;
  Inc(FTypesCount);
end;

procedure TSVGPathParser.AddPt(const Pt: TSvgPoint; AMoveTo: boolean);
var
 Cap:integer;
begin
  Cap:=Length(DPts);
  if Cap = FPtsCount then
     Setlength(DPts,Cap+64);
  DPts[FPtsCount]:= Pt;
  Inc(FPtsCount);
  if AMoveTo then
     AddTag(psMoveTo)
  else
     AddTag(psLineTo);
end;

procedure TSVGPathParser.AddBezier(const P1, P2, P3: TSvgPoint);
var
 Cap:integer;
begin
  Cap:=Length(DPts);
  if Cap < FPtsCount+3 then
     Setlength(DPts,Cap+64);
  DPts[FPtsCount]  := P1;
  DPts[FPtsCount+1]:= P2;
  DPts[FPtsCount+2]:= P3;
  Inc(FPtsCount,3);
  AddTag(psBezierTo);
end;

procedure TSVGLoaderBase.ParseStyle(Style:TStrings);
var
    Value:string;
    function ReadKey(const AName:string;var AOut:string):boolean;
    begin
       AOut:= Style.Values[AName];
       Result:= AOut <> '';//| 'none'  to add
    end;
    procedure InheritedAttr();
    var
      Op:Double;
    begin   //keep order
      if ReadKey('stroke-opacity',Value) then
         FStk.PenOpacity:= FStk.PenOpacity*SVGParseValue(Value,True);
      if ReadKey('fill-opacity',Value) then
         FStk.FillOpacity:=FStk.FillOpacity*SVGParseValue(Value,True);
      if ReadKey('opacity',Value) then
      begin
         Op:=SVGParseValue(Value,True);
         FStk.FillOpacity:=FStk.FillOpacity*Op;
         FStk.PenOpacity:= FStk.PenOpacity*Op;
      end;
    end;
    procedure ProcessFontFamily(const AStr:string);
    var
      t:string;
      P:integer;
    begin
      if AStr='' then     //choose only first name
         Exit;
      P:=Pos(',',AStr);
       if P=0 then
         t:=AStr
       else
         t:=Copy(AStr,1,P-1);

       if t='serif' then
         FStk.FontFamily:='Times New Roman'
       else if t='sans-serif' then
         FStk.FontFamily:='Helvetica'
       else if t='monospace' then
         FStk.FontFamily:='Courier'
       else
         FStk.FontFamily:=t
    end;
    procedure ProcessFontSize(const AStr:string);
    var
      V:Double;
    begin
       V:=SVGParseLength(AStr, FStk.FontSize);
       FStk.FontSize:=Round(V);
    end;
var
   I,Sz:integer;
   t:string;
begin
    InheritedAttr();
    if ReadKey('stroke-width',Value) then
       FStk.PenWidth:= SVGParseLength(Value,LengthRef);

    if ReadKey('stroke',Value) then
       FStk.PenColor:= SVGParseColor(Value);
    if ReadKey('fill',Value) then
       FStk.FillColor:= SVGParseColor(Value);

    if ReadKey('stroke-linecap',Value) then
    begin
       if Value='square' then
          FStk.LineCap:= svgSquare
       else if Value='round' then
          FStk.LineCap:= svgRound
       else if Value='butt' then
          FStk.LineCap:= svgButt
    end;
    if ReadKey('stroke-linejoin',Value) then
    begin
       if Value='miter' then
          FStk.LineJoin:= svgMiter
       else if Value='round' then
          FStk.LineJoin:= svgRound
       else if Value='bevel' then
          FStk.LineJoin:= svgBevel
    end;
    if ReadKey('stroke-miterlimit',Value) then
       FStk.MiterLimit:= SVGParseLength(Value,LengthRef);
    if ReadKey('fill-rule',Value) then
    begin
       if Value='nonzero' then
          FStk.FillMode:= svgNonZero
       else if Value='evenodd' then
          FStk.FillMode:= svgEvenOdd;
    end;
    if ReadKey('stroke-dashoffset',Value) then
       FStk.PenDashOffset:= SVGParseValue(Value,False);
    if ReadKey('stroke-dasharray',Value) then
       FStk.PenDashArray:= SVGParseStrokeDashArray(Value);

    if ReadKey('display',Value) then //for test
       if Value='none' then
         FStk.Display:=svgNone
       else
         FStk.Display:=svgInline;
    if ReadKey('font-family',Value) then
       ProcessFontFamily(Value);
    if ReadKey('font-size',Value) then
       ProcessFontSize(Value);
    if ReadKey('font-weight',Value) then
    begin
       if Value='bold' then
          FStk.FontWeight:=svgBold
       else if Value='normal' then
          FStk.FontWeight:=svgNormal;
    end;
    if ReadKey('font-style',Value) then
    begin
       if Value='italic' then
          FStk.FontStyle:=svgItalic
       else if Value='normal' then
          FStk.FontStyle:=svgNormal;
    end;
    if ReadKey('text-decoration',Value) then
     with TStringList.Create do
      try
        Delimiter := ' ';
        DelimitedText := Value;
        if IndexOf('underline') > -1 then
           FStk.FontDecoration:=svgUnderline;
        if IndexOf('none') > -1 then
          FStk.FontDecoration:=svgNone;
      finally
        Free;
      end;
    if ReadKey('font',Value) then
     with TStringList.Create do
      try
        Delimiter := ' ';
        QuoteChar:='''';
        DelimitedText := Value;
        for I := 0 to Count - 1 do
        begin
          t :=Strings[I];
          if t='underline' then
             FStk.FontDecoration:=svgUnderline
          else if t='bold' then
             FStk.FontWeight:=svgBold
          else if t='italic' then
             FStk.FontStyle:=svgItalic
          else if t='normal' then
          begin
             FStk.FontWeight:=svgNormal;
             FStk.FontStyle:=svgNormal;
          end else if t[1] in ['0'..'9','.'] then
          begin
             ProcessFontSize(t)
          end else
             ProcessFontFamily(t);
        end;
      finally
        Free;
      end;
    if ReadKey('text-anchor',Value) then
    begin
       if Value='start' then
          FStk.TxtAnchor:=svgStart
       else if Value='middle' then
          FStk.TxtAnchor:=svgMiddle
       else if Value='end' then
          FStk.TxtAnchor:=svgEnd
    end;
    if ReadKey('text-align',Value) then
    begin
       if Value='left' then
          FStk.TxtAlign:=svgLeft
       else if Value='center' then
          FStk.TxtAlign:=svgCenter
       else if Value='right' then
          FStk.TxtAlign:=svgRight
       else if Value='justified' then
          FStk.TxtAlign:=svgJustified
    end;
end;

procedure TSVGLoaderBase.MergeAttrsNodeStyle(AList:TStringList;ANode: TNodeType);
var
 I:integer;
 nKey,Value:string;
begin
    AList.CaseSensitive:=True;
    AList.BeginUpdate();
    try
        for I:=0 to ANode.AttributeNodes.Count-1 do
        with ANode.AttributeNodes[I] do
          begin
            nKey := nodeName;
            Value:= VarToStr(nodeValue);
            nKey:=Lowercase(nKey);
            if Sametext(Copy(nKey,1,4),'svg:') then
               nKey:=Copy(nKey,5,MAXINT);
            AList.Values[nKey]:=Value;
         end;
         if ANode.HasAttribute('style')then
            SVGParseStyle(AList,ANode.GetAttribute('style'));
    finally
       AList.EndUpdate();
    end;
end;

procedure TSVGLoaderBase.ProcessNodeStyle(ANode: TNodeType;ATag:TSVGNode);
var
  List:THashedStringList;
  procedure _ParseClassStyle();
  var
     Style:string;
  begin
      if ANode.HasAttribute('class') then
      begin
         Style:=FStyles.Values['.'+VarToStr(ANode.GetAttribute('class'))];
         if Style <> '' then
           SVGParseStyle(List,Style);
      end;
      if ANode.HasAttribute('id') then
      begin
         Style:=FStyles.Values['#'+VarToStr(ANode.GetAttribute('id'))];
         if Style <> '' then
           SVGParseStyle(List,Style);
      end;
  end;
  procedure _ParseTagStyle();
  begin
    if FTagsStyle[ATag] <> '' then
       SVGParseStyle(List,FTagsStyle[ATag]);
  end;
begin
    List:=THashedStringList.Create; //deleted in proccess_obj
    MergeAttrsNodeStyle(List,ANode);
    if ATag=snUse then
    begin
      _ParseTagStyle();
      _ParseClassStyle();
      MergeAttrsNodeStyle(List,ANode);
    end else begin
      MergeAttrsNodeStyle(List,ANode);
      _ParseClassStyle();
      _ParseTagStyle();
    end;
    FC.Attrs:=List;
    ParseStyle(List);
end;

procedure TSVGLoaderBase.BuildLinearGradient(const AName,AUrl:string;const Pt1,Pt2:TSvgPoint;
           const Items: TArrayGradientColor;Mat:PMatrix);
begin
end;

function TSVGLoaderBase.GetColorUrl(const AName: string): integer;
begin
  Result:=0;
end;

procedure TSVGLoaderBase.BuildRadialGradient(const AName, AUrl: string;
  const Focal, Center: TSvgPoint; Radius: Single;
  const Items: TArrayGradientColor;Mat:PMatrix);
begin

end;

initialization
  PixelsPerInch:=Screen.PixelsPerInch;
  LoadColorTable();
finalization
  ColorTable.Free;
end.
