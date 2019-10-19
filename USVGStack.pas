unit USVGStack;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Dialogs,UMatrix;
type
  TArrayOfSingle=array of Single;
  TArrayOfString=array of string;
  TArrayOfDouble=array of Double;

  TSvgStlValue=(svgNone,svgButt,svgSquare,lcRound,svgMiter,svgBevel,svgRound,
                svgEvenOdd,svgNonZero,
                svgNormal,svgItalic,svgBold,svgUnderline,
                svgStart,svgMiddle,svgEnd,
                svgLeft,svgCenter,svgRight,svgJustified,
                svgInline,
                svgVisible);
  TUsedField=(usMatrix,
              usFillColor,usPenColor,usPenWidth,usFillOpacity,usPenOpacity,
              usLineCap,usLineJoin,usMiterLimit,usFillMode,usPenDashOffset,
              usPenDashArray,
              usDisplay,usVisibility,
              usFontFamily,usFontStyle,usFontWeight,usFontSize,usFontDecoration,
              usTextAnchor,usTextAlign);
  TRecordCat=(rsWorld,rsStl1,rsStl2,rsStl3,rsFont);
  TFields=set of TUsedField;
  TRecordCats=set of TRecordCat;
  TSvgStlValues=set of TSvgStlValue;
  PSVGContext=^TSVGContext;
  TSVGContext=record
    Cats:TRecordCats;
    Fields:TFields;
    World:record
      mMatrix:TMatrix;
    end;
    Stl1:record
      mFillColor:TColor;  //fill
      mPenColor:TColor;   //stroke
      mPenWidth:Single;   //stroke-width
      mFillOpacity:Single;//fill-opacity
      mPenOpacity:Single; //stroke-opacity
    end;
    Stl2:record
      mLineCap:TSvgStlValue;  //stroke-linecap
      mLineJoin:TSvgStlValue;//stroke-linejoin
      mMiterLimit:Single; //stroke-miterlimit
      mFillMode:TSvgStlValue;//fill-rule
      mPenDashOffset:Single;//stroke-dashoffset
      mPenDashArray:TArrayOfSingle;//stroke-dasharray
    end;
    Stl3:record
      mDisplay:TSvgStlValue; //display
      mVisibility:TSvgStlValue;//visibility
      mTxtAnchor:TSvgStlValue;//text-anchor
      mTxtAlign:TSvgStlValue;//text-align
      mExtra:TSvgStlValues;
    end;
    Font:record
      mFamily:string;
      mSize:integer;
      mStyle:TSvgStlValue;
      mWeight:TSvgStlValue;
      mDecoration:TSvgStlValue;
    end;
  end;
  TSVGContextArray=array[0..0]of TSVGContext;
  PSVGContextArray=^TSVGContextArray;
  TSVGStack=class
  private
    FData:PSVGContextArray; //array of TSVGContext
    FCap:integer;
    FCount:Integer;
    PCurr:PSVGContext;
    FWorld:TSVGContext;
    procedure SetFillColor(const Value: TColor);
    procedure SetFillMode(const Value: TSvgStlValue);
    procedure SetFillOpacity(const Value: Single);
    procedure SetLineCap(const Value: TSvgStlValue);
    procedure SetLineJoin(const Value: TSvgStlValue);
    procedure SetMiterLimit(const Value: Single);
    procedure SetPenColor(const Value: TColor);
    procedure SetPenDashArray(const Value: TArrayOfSingle);
    procedure SetPenDashOffset(const Value: Single);
    procedure SetPenOpacity(const Value: Single);
    procedure SetPenWidth(const Value: Single);
    function Grow: PSVGContext;
    procedure SaveStl1;
    procedure SaveStl2;
    procedure SaveStl3;
    procedure SaveWorld;
    procedure SaveFont;
    procedure SetDisplay(const Value: TSvgStlValue);
    procedure SetVisibility(const Value: TSvgStlValue);
    procedure SetFontDecoration(const Value: TSvgStlValue);
    procedure SetFontFamily(const Value: string);
    procedure SetFontSize(const Value: integer);
    procedure SetFontStyle(const Value: TSvgStlValue);
    procedure SetFontWeight(const Value: TSvgStlValue);
    procedure SetTxtAnchor(const Value: TSvgStlValue);
    procedure SetTxtAlign(const Value: TSvgStlValue);
  public
    destructor Destroy();override;
    procedure EndCapture();
    property Context:TSVGContext read FWorld;
    procedure Import(const ASrc:TSVGContext);
    function  BeginCapture():integer;
    property UsedFields:TFields read FWorld.Fields;
    property Cats:TRecordCats read FWorld.Cats;
    procedure SetMatrix(const Value:TMatrix);
    property Matrix:TMatrix read FWorld.World.mMatrix write SetMatrix;
    property FillColor:TColor read  FWorld.Stl1.mFillColor write SetFillColor;  //fill
    property PenColor:TColor read  FWorld.Stl1.mPenColor write SetPenColor;   //stroke
    property PenWidth:Single read  FWorld.Stl1.mPenWidth write SetPenWidth;   //stroke-width
    property FillOpacity:Single read  FWorld.Stl1.mFillOpacity write SetFillOpacity;//fill-opacity
    property PenOpacity:Single read  FWorld.Stl1.mPenOpacity write SetPenOpacity; //stroke-opacity
    property LineCap:TSvgStlValue read  FWorld.Stl2.mLineCap write SetLineCap;  //stroke-linecap
    property LineJoin:TSvgStlValue read  FWorld.Stl2.mLineJoin write SetLineJoin;//stroke-linejoin
    property MiterLimit:Single read  FWorld.Stl2.mMiterLimit write SetMiterLimit; //stroke-miterlimit
    property FillMode:TSvgStlValue read  FWorld.Stl2.mFillMode write SetFillMode;//fill-rule
    property PenDashOffset:Single read  FWorld.Stl2.mPenDashOffset write SetPenDashOffset;//stroke-dashoffset
    property PenDashArray:TArrayOfSingle read  FWorld.Stl2.mPenDashArray write SetPenDashArray;//stroke-dasharray }
    property Display:TSvgStlValue read FWorld.Stl3.mDisplay write SetDisplay;
    property Visibility:TSvgStlValue read FWorld.Stl3.mVisibility write SetVisibility;
    property TxtAnchor:TSvgStlValue read FWorld.Stl3.mTxtAnchor write SetTxtAnchor;
    property TxtAlign:TSvgStlValue read FWorld.Stl3.mTxtAlign write SetTxtAlign;
    property ExtraStl:TSvgStlValues read FWorld.Stl3.mExtra;

    property FontFamily:string read FWorld.Font.mFamily write SetFontFamily;
    property FontSize:integer read FWorld.Font.mSize write SetFontSize;
    property FontStyle:TSvgStlValue read FWorld.Font.mStyle write SetFontStyle;
    property FontWeight:TSvgStlValue read FWorld.Font.mWeight write SetFontWeight;
    property FontDecoration:TSvgStlValue read FWorld.Font.mDecoration write SetFontDecoration;
    procedure ExtraInclude(Fld:TUsedField;value:TSvgStlValue);
    procedure ExtraExclude(Fld:TUsedField;value:TSvgStlValue);
  end;
procedure UpdateContext(const Src:TSVGContext;var Dest: TSVGContext);
implementation

destructor TSVGStack.Destroy;
begin
 // Finalize(FData^,FCount);
 // Freemem(FData);
  inherited;
end;

function TSVGStack.Grow():PSVGContext;
begin
  if FCap=FCount then
  begin
    FCap:= FCap  + 8;
     ReallocMem(FData,FCap* SizeOf(TSVGContext));
   // FCap:=fcap+4;
   // SetLength(FData,FCap);
  end;
  Result:=@FData[FCount];
  Inc(FCount);
end;

function TSVGStack.BeginCapture: integer;
begin
  PCurr:= Grow();
  Initialize(PCurr^,1);
  PCurr.Cats:= FWorld.Cats;
  PCurr.Fields:= FWorld.Fields;
  FWorld.Cats:=[];
  FWorld.Fields:=[];
end;

procedure TSVGStack.EndCapture();
begin
   if rsWorld in FWorld.Cats then
     FWorld.World:=PCurr.World;
   if rsStl1 in FWorld.Cats then
     FWorld.Stl1:=PCurr.Stl1;
   if rsStl2 in FWorld.Cats then
     FWorld.Stl2:=PCurr.Stl2;
   if rsStl3 in FWorld.Cats then
     FWorld.Stl3:=PCurr.Stl3;
   if rsFont in FWorld.Cats then
     FWorld.Font:=PCurr.Font;
   FWorld.Cats:=PCurr.Cats;
   FWorld.Fields:=PCurr.Fields;
   Finalize(PCurr^,1);
 // Finalize(Fdata[FCount-1],1) ;  }
  // FWorld:=Fdata[FCount-1];
   if FCount=0 then
    raise exception.Create('kkk');
   Dec(FCount);
   PCurr:=@FData[FCount-1];
end;

procedure TSVGStack.ExtraExclude(Fld: TUsedField; value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,Fld);
  Exclude(FWorld.Stl3.mExtra,Value);
end;

procedure TSVGStack.ExtraInclude(Fld: TUsedField; value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,Fld);
  Include(FWorld.Stl3.mExtra,Value);
end;

procedure TSVGStack.SaveWorld();
begin
  if (rsWorld in FWorld.Cats) then
     Exit;
  include(FWorld.Cats,rsWorld);
  PCurr.World:=FWorld.World;
end;
procedure TSVGStack.SaveFont;
begin
  if (rsFont in FWorld.Cats) then
     Exit;
  include(FWorld.Cats,rsFont);
  PCurr.Font:=FWorld.Font;
end;

procedure TSVGStack.SaveStl1();
begin
  if (rsStl1 in FWorld.Cats) then
     Exit;
  include(FWorld.Cats,rsStl1);
  PCurr.Stl1:=FWorld.Stl1;
end;

procedure TSVGStack.SaveStl2();
begin
  if (rsStl2 in FWorld.Cats) then
     Exit;
  include(FWorld.Cats,rsStl2);
  PCurr.Stl2:=FWorld.Stl2;
end;

procedure TSVGStack.SaveStl3;
begin
  if (rsStl3 in FWorld.Cats) then
     Exit;
  include(FWorld.Cats,rsStl3);
  PCurr.Stl3:=FWorld.Stl3;
end;

procedure TSVGStack.SetFillColor(const Value: TColor);
begin
  SaveStl1();
  include(FWorld.Fields,usFillColor);
  FWorld.Stl1.mFillColor := Value;
end;

procedure TSVGStack.SetFillMode(const Value: TSvgStlValue);
begin
  SaveStl2();
  include(FWorld.Fields,usFillMode);
  FWorld.Stl2.mFillMode := Value;
end;

procedure TSVGStack.SetFillOpacity(const Value: Single);
begin
  SaveStl1();
  include(FWorld.Fields,usFillOpacity);
  FWorld.Stl1.mFillOpacity := Value;
end;

procedure TSVGStack.SetFontDecoration(const Value: TSvgStlValue);
begin
  SaveFont();
  include(FWorld.Fields,usFontDecoration);
  FWorld.Font.mDecoration := Value;
end;

procedure TSVGStack.SetFontFamily(const Value: string);
begin
  SaveFont();
  include(FWorld.Fields,usFontFamily);
  FWorld.Font.mFamily := Value;
end;

procedure TSVGStack.SetFontSize(const Value: integer);
begin
  SaveFont();
  include(FWorld.Fields,usFontSize);
  FWorld.Font.mSize := Value;
end;

procedure TSVGStack.SetFontStyle(const Value: TSvgStlValue);
begin
  SaveFont();
  include(FWorld.Fields,usFontStyle);
  FWorld.Font.mStyle := Value;
end;

procedure TSVGStack.SetFontWeight(const Value: TSvgStlValue);
begin
  SaveFont();
  include(FWorld.Fields,usFontWeight);
  FWorld.Font.mWeight := Value;
end;

procedure TSVGStack.SetLineCap(const Value: TSvgStlValue);
begin
  SaveStl2();
  include(FWorld.Fields,usLineCap);
  FWorld.Stl2.mLineCap := Value;
end;

procedure TSVGStack.SetLineJoin(const Value: TSvgStlValue);
begin
  SaveStl2();
  include(FWorld.Fields,usLineJoin);
  FWorld.Stl2.mLineJoin := Value;
end;

procedure TSVGStack.SetMiterLimit(const Value: Single);
begin
  SaveStl2();
  include(FWorld.Fields,usMiterLimit);
  FWorld.Stl2.mMiterLimit := Value;
end;

procedure TSVGStack.SetPenColor(const Value: TColor);
begin
  SaveStl1();
  include(FWorld.Fields,usPenColor);
  FWorld.Stl1.mPenColor := Value;
end;

procedure TSVGStack.SetPenDashArray(const Value: TArrayOfSingle);
begin
  SaveStl2();
  include(FWorld.Fields,usPenDashArray);
  FWorld.Stl2.mPenDashArray := Value;
end;

procedure TSVGStack.SetPenDashOffset(const Value: Single);
begin
  SaveStl2();
  include(FWorld.Fields,usPenDashOffset);
  FWorld.Stl2.mPenDashOffset := Value;
end;

procedure TSVGStack.SetPenOpacity(const Value: Single);
begin
  SaveStl1();
  include(FWorld.Fields,usPenOpacity);
  FWorld.Stl1.mPenOpacity := Value;
end;

procedure TSVGStack.SetPenWidth(const Value: Single);
begin
  SaveStl1();
  include(FWorld.Fields,usPenWidth);
  FWorld.Stl1.mPenWidth := Value;
end;

procedure TSVGStack.SetTxtAlign(const Value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,usTextAlign);
  FWorld.Stl3.mTxtAlign := Value;
end;

procedure TSVGStack.SetTxtAnchor(const Value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,usTextAnchor);
  FWorld.Stl3.mTxtAnchor := Value;
end;

procedure TSVGStack.SetVisibility(const Value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,usVisibility);
  FWorld.Stl3.mVisibility := Value;
end;


procedure TSVGStack.SetDisplay(const Value: TSvgStlValue);
begin
  SaveStl3();
  include(FWorld.Fields,usDisplay);
  FWorld.Stl3.mDisplay := Value;
end;

procedure TSVGStack.SetMatrix(const Value: TMatrix);
begin
  SaveWorld();
  include(FWorld.Fields,usMatrix);
  FWorld.World.mMatrix := Value;
end;

procedure UpdateContext(const Src:TSVGContext;var Dest: TSVGContext);
begin
  with Src do
  begin
       Dest.Cats:=Dest.Cats+ Cats;
       Dest.Fields:=Dest.Fields+Fields;
       if rsWorld in Cats then
       begin
         if usMatrix in Fields then
           Dest.World.mMatrix:= World.mMatrix;
       end;
       if rsStl1 in Cats then
       begin
         if usFillColor in Fields then
           Dest.Stl1.mFillColor:= Stl1.mFillColor;
         if usPenColor in Fields then
           Dest.Stl1.mPenColor:=Stl1.mPenColor;
         if usPenWidth in Fields then
           Dest.Stl1.mPenWidth:=Stl1.mPenWidth;
         if usFillOpacity in Fields then
           Dest.Stl1.mFillOpacity:=Stl1.mFillOpacity;
         if usPenOpacity in Fields then
           Dest.Stl1.mPenOpacity:=Stl1.mPenOpacity;
       end;
       if rsStl2 in Cats then
       begin
         if usLineCap in Fields then
           Dest.Stl2.mLineCap:=Stl2.mLineCap;
         if usLineJoin in Fields then
           Dest.Stl2.mLineJoin:=Stl2.mLineJoin;
         if usMiterLimit in Fields then
           Dest.Stl2.mMiterLimit:=Stl2.mMiterLimit;
         if usFillMode in Fields then
           Dest.Stl2.mFillMode:=Stl2.mFillMode;
         if usPenDashOffset in Fields then
           Dest.Stl2.mPenDashOffset:=Stl2.mPenDashOffset;
         if usPenDashArray in Fields then
           Dest.Stl2.mPenDashArray:=Stl2.mPenDashArray;
       end;
       if rsStl3 in Cats then
       begin
         if usDisplay in Fields then
           Dest.Stl3.mDisplay:=Stl3.mDisplay;
         if usVisibility in Fields then
           Dest.Stl3.mVisibility:=Stl3.mVisibility;
         if usTextAnchor in Fields then
           Dest.Stl3.mTxtAnchor:=Stl3.mTxtAnchor;
         if usTextAlign in Fields then
           Dest.Stl3.mTxtAlign:=Stl3.mTxtAlign;
         if usTextAlign in Fields then
           Dest.Stl3.mTxtAlign:=Stl3.mTxtAlign;
       end;
       if rsFont in Cats then
       begin
         if usFontFamily in Fields then
           Dest.Font.mFamily:=Font.mFamily;
         if usFontStyle in Fields then
           Dest.Font.mStyle:=Font.mStyle;
         if usFontWeight in Fields then
           Dest.Font.mWeight:=Font.mWeight;
         if usFontSize in Fields then
           Dest.Font.mSize:=Font.mSize;
         if usFontDecoration in Fields then
           Dest.Font.mDecoration:=Font.mDecoration;
       end;
  end;
end;

procedure TSVGStack.Import(const ASrc: TSVGContext);
begin
   SaveWorld();
   SaveStl1();
   SaveStl2();
   SaveStl3();
   SaveFont();
   UpdateContext(ASrc,FWorld);
end;

end.
