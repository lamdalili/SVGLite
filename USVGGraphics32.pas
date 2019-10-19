unit USVGGraphics32;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,UMatrix,USVG,GR32, GR32_Image, GR32_Layers,GR32_Transforms,
  GR32_VectorUtils,GR32_Polygons, GR32_Paths, GR32_Brushes,GR32_ColorGradients,
  UPolylines;
type
  TGradMat=class
  public
     UrlRef:TGradMat;
     Colors: TArrayGradientColor;
     IsRadialGradient:boolean;
     Matrix:TMatrix;
     //Linear
     FLinearStart: TSvgPoint;
     FLinearEnd: TSvgPoint;
     //Radial
     Focal:TSvgPoint;
     Center:TSvgPoint;
     Radius:Single;
     function CreateTable(Alpha:byte):TColor32LookupTable;
  end;
  TStrokeBrush=class(GR32_Brushes.TStrokeBrush)
  public
    procedure PolyPolygonFS(Renderer: TCustomPolygonRenderer;
      const Points: TArrayOfArrayOfFloatPoint;
      const ClipRect: TFloatRect; Transformation: TTransformation;
      Closed: Boolean); override;
  end;
  TDashedBrush=class(TStrokeBrush)
  private
    FDashArray: TArrayOfFloat;
  public
    DashOffset: TFloat;
    Pathlength: TFloat;
    procedure SetDashArray(const ADashArray: array of TFloat);
    procedure PolyPolygonFS(Renderer: TCustomPolygonRenderer;
      const Points: TArrayOfArrayOfFloatPoint;
      const ClipRect: TFloatRect; Transformation: TTransformation;
      Closed: Boolean); override;
  end;
  TClipRendrer=class(TPolygonRenderer32VPR)
  public
    Enabled:boolean;
    PathRect:TFloatRect;
    //clip before transform
    procedure PolyPolygonFS(const Points: TArrayOfArrayOfFloatPoint;
      const ClipRect: TFloatRect; Transformation: TTransformation);override;
  end;

  TSVGLoader=class(TSVGLoaderBase)
  protected
    FClipRendrer:TClipRendrer;
    FUrlColors:TStringHashEx;
    FGradFillList:TList;
    FBitmap32:TBitmap32;
    FCanvas:TCanvas32;
    FSolid: TSolidBrush;
    FStroke: TStrokeBrush;
    FDashed: TDashedBrush;
    FMatrix:TAffineTransformation;
    procedure Rectangle(const APos,Size,Radius:TSvgPoint);override;
    procedure Ellipse(const Center,Radius:TSvgPoint);override;
    procedure Poly(const Pts:array of TSvgPoint;AClosed:boolean);override;
    procedure Path(const Pts: array of TSvgPoint;const PtTypes: array of TPathSegType);override;
    procedure Line(const P1,P2:TSvgPoint);override;
    procedure Text(const AStr:string;const APos:TSvgPoint;AFont:TFont;const InlineSize:Extended);override;
    function BuildGradientBase(const AName, AUrl: string;const Items: TArrayGradientColor;Mat:PMatrix): TGradMat;
    function TryUrlFill(AColor: integer; var P:TGradMat): boolean;
    function Preparefiller(AFillData:TGradMat;Alpha:byte):TCustomPolygonFiller;
    procedure BeforeProcessNode(NK:TSVGNode);override;
    procedure AfterProcessNode(NK:TSVGNode);override;
    procedure BuildLinearGradient(const AName,AUrl:string;const Pt1,Pt2:TSvgPoint;
                                  const Items:TArrayGradientColor;MAt:PMatrix);override;
    function GetColorUrl(const AName:string):integer;override;
    procedure BuildRadialGradient(const AName,AUrl:string;const AFocal,ACenter:TSvgPoint;ARadius:Single;
                                  const Items:TArrayGradientColor;Mat:PMatrix);override;
  public
    constructor Create(ABitmap32:TBitmap32);
    destructor Destroy();override;
  end;

implementation
uses math,USVGStack,GR32_Text_VCL,UTxtToPath;
const SVG_GR32:array[svgButt..svgNonZero]of integer=(
                     Ord(esButt),Ord(esSquare),Ord(esRound),
                     Ord(jsMiter),Ord(jsBevel),Ord(jsRound),
                     Ord(pfAlternate),Ord(pfWinding));

function GrFPoint(const Pt:TSvgPoint):TFloatPoint;
begin
   Result.X :=Pt.X;
   Result.Y :=Pt.Y;
end;
function IsClosedPath(const APath:TArrayOfFloatPoint):boolean;
var
 P1,P2:TFloatPoint;
 L:integer;
begin
  Result:=False;
  L:=Length(APath);
  if L < 2 then
     Exit;
  P1:=APath[0];
  P2:=APath[L-1];
  Result:=(P1.X=P2.X)and(P1.Y=P2.Y);
end;
function ClipPolyPolygon(const Points:TArrayOfArrayOfFloatPoint;const ARect:TFloatRect):TArrayofArrayOfFloatpoint;
var
 I:integer;
begin
 Setlength(Result,Length(Points));
 for I := 0 to Length(Points) - 1 do
    Result[I]:=ClipPolygon(Points[I],ARect);
end;
{ TStrokeBrush }

procedure TStrokeBrush.PolyPolygonFS(Renderer: TCustomPolygonRenderer;
  const Points: TArrayOfArrayOfFloatPoint; const ClipRect: TFloatRect;
  Transformation: TTransformation; Closed: Boolean);
var
  APoints: TArrayOfArrayOfFloatPoint;
begin
  APoints := SVGBuildPolyPolyLine(Points,StrokeWidth, JoinStyle,
    EndStyle, MiterLimit);
  UpdateRenderer(Renderer);
  Renderer.PolyPolygonFS(APoints, ClipRect, Transformation);
end;

{ TDashedBrush }

procedure TDashedBrush.PolyPolygonFS(Renderer: TCustomPolygonRenderer;
  const Points: TArrayOfArrayOfFloatPoint; const ClipRect: TFloatRect;
  Transformation: TTransformation; Closed: Boolean);
var
  I: Integer;
  Pts:TArrayOfFloatPoint;
  R:TArrayOfArrayOfFloatPoint;
begin
  for I := 0 to High(Points) do
  begin
     Pts:=Points[I];
     R:=SVGBuildDashedLine(Pts, FDashArray, DashOffset,IsClosedPath(Pts),Pathlength);
     inherited PolyPolygonFS(
       Renderer, R,
       ClipRect, Transformation, False);
  end;
end;
procedure TDashedBrush.SetDashArray(const ADashArray: array of TFloat);
var
  L: Integer;
begin
  L := Length(ADashArray);
  SetLength(FDashArray, L);
  Move(ADashArray[0], FDashArray[0], L * SizeOf(TFloat));
  Changed;
end;
{ TClipRendrer }

procedure TClipRendrer.PolyPolygonFS(const Points: TArrayOfArrayOfFloatPoint;
      const ClipRect: TFloatRect; Transformation: TTransformation);
var
  Polys:TArrayOfArrayOfFloatPoint;
begin
   if Enabled then
   begin
      Polys:=ClipPolyPolygon(Points,PathRect);
      inherited PolyPolygonFS(Polys,ClipRect,Transformation);
   end else
        inherited PolyPolygonFS(Points,ClipRect,Transformation);
end;

procedure TSVGLoader.Text(const AStr: string; const APos: TSvgPoint;
  AFont: TFont; const InlineSize: Extended);
var
  R:TFloatRect;
  Glyphs:TArrayOfGlyphs;
  I,J :integer;
  Path:TArrayOfArrayOfFloatPoint;
  Ph:TArrayOfFloatPoint;
  Align:TTxtAlignement;
  W:TFloat;
begin
  case FStk.TxtAlign of
      svgCenter:Align:=tacCenter;
       svgRight:Align:=tacRight;
   svgJustified:Align:=tacJustify;
  else
      Align:=tacLeft;
  end;
  R.TopLeft:=GrFPoint(APos);
  R.BottomRight:=FloatPoint(APos.X+InlineSize,APos.Y);
  case FStk.TxtAnchor of
     svgMiddle:begin
       W:=InlineSize / 2;
       R:=FloatRect(APos.X-W,APos.Y,APos.X+W,APos.Y);
       Align:=tacCenter;
     end;
     svgEnd:begin
       R:=FloatRect(APos.X-InlineSize,APos.Y,APos.X,APos.Y);
       Align:=tacRight;
     end;

  end;


  Glyphs:=ScriptToPath(AStr,AFont,R,Align);
  for I := 0 to Length(Glyphs) - 1 do
  begin
    Path:=Glyphs[I];
    for J := 0 to Length(Path) - 1 do  //self intersect may occure
     FCanvas.Polygon(Path[J]);
  end;
end;

function TSVGLoader.TryUrlFill(AColor:integer;var P:TGradMat):boolean;
var
 idx:integer;
begin
  P:=nil;
  Result:=((AColor and $FF000000)<> 0 )and((AColor shr 24 )=$25);
  if Result then
  begin
     idx:= AColor and $FFFFFF;
     Result:=(idx >0)and (Idx < FGradFillList.Count);
     if Result then
        P :=FGradFillList[idx];
  end;
end;
procedure TSVGLoader.Path(const Pts: array of TSvgPoint;
  const PtTypes: array of TPathSegType);
var
  I,L,J:integer;
  Start,P,C1,C2:TFloatPoint;
begin
  L:=Length(Pts);
  if L < 2 then
     Exit;
  J:=0;
  FCanvas.BeginUpdate();
  for I := 0 to Length(PtTypes)-1 do
    case PtTypes[I] of
      psMoveTo:begin
            P:= GrFPoint(Pts[J]);
            Start:=P;
            inc(J);
            FCanvas.MoveTo(Start);
        end;
      psLineTo:begin
            P:= GrFPoint(Pts[J]);
            FCanvas.LineTo(P);
            inc(J);
        end;
       psBezierTo:begin
            C1:=GrFPoint(Pts[J]);
            C2:=GrFPoint(Pts[J+1]);
            P :=GrFPoint(Pts[J+2]);
            FCanvas.CurveTo(C1,C2,P);
            inc(J,3);
        end;
       psClose:begin
          FCanvas.EndPath(True)
        end;
    end;
    FCanvas.EndPath();
    FCanvas.EndUpdate();
end;

procedure TSVGLoader.Poly(const Pts: array of TSvgPoint; AClosed: boolean);
var
 I,L:integer;
begin
   L:=Length(Pts);
   if L < 2 then
      Exit;
   with Pts[0] do
     FCanvas.MoveTo(X,Y);
   for I:=1 to L-1 do
    with Pts[I] do
     FCanvas.LineTo(X,Y);
   if AClosed then
   begin
     with Pts[0] do
      FCanvas.LineTo(X,Y);
   end;
   FCanvas.EndPath(AClosed);
end;

procedure TSVGLoader.Rectangle(const APos, Size, Radius: TSvgPoint);
begin
  if (Radius.X=0)or (Radius.Y=0) then
   FCanvas.Rectangle(FloatRect(APos.X,APos.Y,APos.X+Size.X,APos.Y+Size.Y))
  else
   FCanvas.RoundRect(FloatRect(APos.X,APos.Y,APos.X+Size.X,APos.Y+Size.Y),Radius.X);
end;

procedure TSVGLoader.Ellipse(const Center, Radius: TSvgPoint);
begin
  FCanvas.Ellipse(Center.X,center.Y,Radius.X,Radius.Y);
end;

procedure TSVGLoader.Line(const P1, P2: TSvgPoint);
begin
  FCanvas.MoveTo(P1.X,P1.Y);
  FCanvas.LineTo(P2.X,P2.Y);
  FCanvas.EndPath();
end;

function TSVGLoader.Preparefiller(AFillData:TGradMat;Alpha:byte):TCustomPolygonFiller;
var
 LinearFiller:TCustomLinearGradientPolygonFiller;
 RadGradFiller:TSVGRadialGradientPolygonFiller;
 D:TFloatRect;
 Mx:TFloatMatrix;
begin
  if AFillData.Matrix.A[2,2]=1 then //has a valid matrix
  begin
    FMatrix.Push();
    move(AFillData.Matrix,Mx,SizeOf(TFloatMatrix));
    Mx:=Mult(FMatrix.Matrix,Mx);
    FMatrix.Clear(Mx);
  end;
  if AFillData.IsRadialGradient then
  begin
      RadGradFiller:=TSVGRadialGradientPolygonFiller.Create(AFillData.CreateTable(Alpha));
      Result:=RadGradFiller;
      with AFillData do
      begin
        D.TopLeft:= FMatrix.Transform(FloatPoint(Center.X - Radius , Center.Y - Radius));
        D.BottomRight:=FMatrix.Transform(FloatPoint(Center.X+ Radius, Center.Y+Radius));
      end;
      RadGradFiller.EllipseBounds:=D;
      RadGradFiller.FocalPoint := FMatrix.Transform(GrFPoint(AFillData.Focal));
  end else begin
      LinearFiller := TLinearGradientPolygonFiller.Create(AFillData.CreateTable(Alpha));
      Result:=LinearFiller;
      LinearFiller.StartPoint := FMatrix.Transform(GrFPoint(AFillData.FLinearStart));
      LinearFiller.EndPoint :=FMatrix.Transform(GrFPoint(AFillData.FLinearEnd));
  end;
  if AFillData.Matrix.A[2,2]=1 then //has a valid matrix
     FMatrix.Pop();
end;

procedure TSVGLoader.BeforeProcessNode(NK: TSVGNode);
var
 alpha1,alpha2:integer;
 FillData:TGradMat;
 Mx:TFloatMatrix;
 Brush:TStrokeBrush;
 C:TColor32;
 S:string;
begin
  if NK=snSvg then
  begin
    C:=SetAlpha(Color32(BGColor),0);
    FBitmap32.SetSize(Ceil(FC.Size.x),Ceil(FC.Size.y));
    FBitmap32.Clear(C);
  end;
  if not(NK  in[snRect,snLine,snCircle,snEllipse,snPolyLine,snPolygon,snPath,snText]) then
     Exit;
  FCanvas.BeginUpdate();
  alpha1:= Round(255*FStk.FillOpacity);
  alpha2:= Round(255*FStk.PenOpacity);
  move(FStk.Matrix,Mx,SizeOf(TFloatMatrix));
  FMatrix.Clear(Mx);
  FSolid.Visible :=FStk.FillColor <> clNone;
  FSolid.Filler:=nil;
  if FSolid.Visible then
  begin
     FSolid.FillColor:=SetAlpha(Color32(FStk.FillColor),alpha1);
     FSolid.FillMode:=TPolyFillMode(SVG_GR32[FStk.FillMode]);
     if TryUrlFill(FStk.FillColor,FillData) then
        FSolid.Filler:=  Preparefiller(FillData,alpha1);
  end;

  FDashed.Visible :=FStk.PenColor <> clNone;;
  FStroke.Visible :=FDashed.Visible;
  FStroke.Filler:=nil;
  FDashed.Filler:=nil;
  if not FDashed.Visible then
     Exit;
  FDashed.Visible :=Length(FStk.PenDashArray) <> 0;
  FStroke.Visible :=not FDashed.Visible;
  if FDashed.Visible then
  begin
     Brush:=FDashed;
     FDashed.DashOffset:=FStk.PenDashOffset;
     FDashed.SetDashArray(FStk.PenDashArray);
     FDashed.Pathlength:=0;
     S:=FC.Attrs.Values['pathlength'];
     if S <> '' then
       FDashed.Pathlength:=SVGParseValue(S,False);
  end else
     Brush:=FStroke;
  if Brush.Visible then
  begin
    Brush.StrokeWidth:=FStk.PenWidth;
    Brush.FillColor:=SetAlpha(Color32(FStk.PenColor),alpha2);
    Brush.EndStyle :=TEndStyle(SVG_GR32[FStk.LineCap]);
    Brush.JoinStyle :=TJoinStyle(SVG_GR32[FStk.LineJoin]);
    Brush.MiterLimit:=Max( FStk.MiterLimit,1);
    if TryUrlFill(FStk.PenColor,FillData) then
       brush.Filler:=  Preparefiller(FillData,alpha2);
  end;
end;

procedure TSVGLoader.AfterProcessNode(NK: TSVGNode);
  procedure FreeFiller(Brush:TSolidBrush);
  begin
     if Assigned(Brush.Filler) then
      begin
         Brush.Filler.Free;
         Brush.Filler:=nil;
      end;
  end;
var
    R:TFloatRect;
begin
  if not(NK  in[snRect,snLine,snCircle,snEllipse,snPolyLine,snPolygon,snPath,snText]) then
     Exit;
  if FStk.Display=svgNone then
     FCanvas.Clear();
  FClipRendrer.Enabled:=FC.UseClip;
  if FC.UseClip then
    with FC.ClipRect do
    begin
        R:=FloatRect(X,Y,W,H);
        FClipRendrer.PathRect:= R;
    end;
  FCanvas.EndUpdate();
  FCanvas.Clear();
  FreeFiller(FSolid);
  FreeFiller(FStroke);
  FreeFiller(FDashed);
  FClipRendrer.Enabled:=False;
end;

constructor TSVGLoader.Create(ABitmap32:TBitmap32);
begin
  inherited Create();
  FBitmap32 :=ABitmap32;
  FCanvas:= TCanvas32.Create(ABitmap32);
  FSolid := TSolidBrush(FCanvas.Brushes.Add(TSolidBrush));
  FStroke:= TStrokeBrush(FCanvas.Brushes.Add(TStrokeBrush));
  FDashed:= TDashedBrush(FCanvas.Brushes.Add(TDashedBrush));
  FUrlColors:=TStringHashEx.Create;
  FGradFillList:=TList.Create;
  FDashed.Visible:=false;
//  FStroke.Visible:=false;
  FGradFillList.Add(nil);//invalid filler
  FMatrix:=TAffineTransformation.Create;
  FCanvas.Transformation:=FMatrix;
  FClipRendrer:=TClipRendrer.Create();
  FCanvas.Renderer:=FClipRendrer;
end;

destructor TSVGLoader.Destroy;
var
 i:integer;
begin
  for I:=0 to FGradFillList.Count-1 do
  begin
    TObject(FGradFillList[I]).Free;
  end;
  FGradFillList.Free;
  FCanvas.Free;
  FMatrix.Free;
  inherited;
end;

function TSVGLoader.GetColorUrl(const AName: string): integer;
begin
  Result:=FUrlColors.ValueOf(Uppercase(AName));
end;

function TSVGLoader.BuildGradientBase(const AName, AUrl: string;const Items: TArrayGradientColor;Mat:PMatrix):TGradMat;
var
  GradMat:TGradMat;
  iD:integer;
begin
   GradMat:=nil;
   if (AName <> '')and TryUrlFill(GetColorUrl(AName),Result) then  //prev declaration
      Result.Colors:=Items
   else begin
      if (AUrl <> '')and not TryUrlFill(GetColorUrl(AUrl),GradMat) then
      begin
         GradMat:=TGradMat.Create();
         iD:=FGradFillList.Add(GradMat)or $25000000;
         FUrlColors.Add(Uppercase(AUrl),iD);
      end;
      Result:=TGradMat.Create();
      Result.UrlRef:=GradMat;
      iD:=FGradFillList.Add(Result)or $25000000;
      FUrlColors.Add(Uppercase(AName),iD);
      Result.Colors:=Items;
      if Assigned(Mat) then
         Result.Matrix:=Mat^;
   end;
end;

procedure TSVGLoader.BuildLinearGradient(const AName, AUrl: string;const Pt1,Pt2:TSvgPoint;
                                     const Items:TArrayGradientColor;Mat:PMatrix);
begin
   with BuildGradientBase(AName,AUrl,Items,Mat) do
   begin
      FLinearStart:=Pt1;
      FLinearEnd :=Pt2;
   end;
end;

procedure TSVGLoader.BuildRadialGradient(const AName,AUrl:string;const AFocal,ACenter:TSvgPoint;ARadius:Single;
                                  const Items:TArrayGradientColor;Mat:PMatrix);
begin
   with BuildGradientBase(AName,AUrl,Items,Mat) do
   begin
     IsRadialGradient:=True;
     Focal:=AFocal;
     Center:=ACenter;
     Radius:=ARadius;
   end;
end;

function TGradMat.CreateTable(Alpha:byte):TColor32LookupTable;
var
  I:integer;
  Gradient: TColor32Gradient;
  GradMat:TGradMat;
begin
  GradMat:=Self;
  if assigned(UrlRef) then
     GradMat:= UrlRef;
  Result := TColor32LookupTable.Create;
  Gradient := TColor32Gradient.Create;
  try
   with GradMat do
    for I:= 0 to Length(Colors)-1do
   with Colors[I] do
    Gradient.AddColorStop(mLGOffset,
         GR32.SetAlpha( GR32.Color32(mLGStopColor),Round(mLGStopOpacity*Alpha)));
    Gradient.FillColorLookUpTable(Result);
  finally
    Gradient.Free;
  end;
end;


end.
