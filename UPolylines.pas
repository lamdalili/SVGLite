unit UPolylines;

interface
uses
  Math, {$IFDEF FPC}Types, {$ENDIF} {$IFDEF COMPILERXE2_UP}Types, {$ENDIF}
  GR32, GR32_Transforms, GR32_Polygons,GR32_VectorUtils;
 function SVGBuildPolyPolyLine(const Points: TArrayOfArrayOfFloatPoint;
  StrokeWidth: TFloat; JoinStyle: TJoinStyle;
  EndStyle: TEndStyle; MiterLimit: TFloat): TArrayOfArrayOfFloatPoint;
function SVGBuildDashedLine(const Points: TArrayOfFloatPoint;
  const DashArray: TArrayOfFloat; DashOffset: TFloat = 0;
  Closed: Boolean = False;Len: TFloat = -1): TArrayOfArrayOfFloatPoint; overload;

implementation
uses
  SysUtils, GR32_Math, GR32_Geometry, GR32_LowLevel;
function SVGBuildDashedLine(const Points: TArrayOfFloatPoint;
  const DashArray: TArrayOfFloat; DashOffset: TFloat = 0;
  Closed: Boolean = False;Len: TFloat=-1): TArrayOfArrayOfFloatPoint;
type
  TSeg=record
   mSz:TFloatPoint;
   mDist:TFloat;
  end;
const
  EPSILON = 1E-4;
var
  I, J, DashIndex, len1, len2: Integer;
  Offset,PathLen, V,R: TFloat;
  Segs:array of TSeg;
  Dashs: TArrayOfFloat;
  procedure AddPoint(X, Y: TFloat);
  var
    K: Integer;
  begin
    K := Length(Result[J]);
    SetLength(Result[J], K + 1);
    Result[J][K].X := X;
    Result[J][K].Y := Y;
  end;

  procedure AddDash(I: Integer);
  var
   Seg:TSeg;
   t:TFloat;
  begin
    Seg:=Segs[I];
    Offset := Offset + Seg.mDist;
    while Offset > DashOffset do
    begin
      t := Offset - DashOffset;
      AddPoint(Points[I].X - t * Seg.mSz.X, Points[I].Y - t * Seg.mSz.Y);
      DashIndex := (DashIndex +1 ) mod Length(Dashs);
      DashOffset := DashOffset + Dashs[DashIndex];
      if Odd(DashIndex) then
      begin
        Inc(J);
        SetLength(Result, J + 1);
      end;
    end;
    if not Odd(DashIndex) then
      AddPoint(Points[I].X, Points[I].Y);
  end;

begin
  Result := nil;
  if Length(Points) <= 0 then Exit;
  V := 0;
  for I := 0 to High(DashArray) do
    V := V + DashArray[I];
  DashOffset := Wrap(-DashOffset, V) - V;
 // if V <= 0 then
 //    Exit;
  Offset := 0;
  DashIndex := -1;
  while DashOffset < 0 do
  begin
    Inc(DashIndex);
    DashOffset := DashOffset + DashArray[DashIndex];
  end;
  J:=High(Points);
  Setlength(Segs,J+1);
  PathLen:=0;
  for I := 0 to J do
  begin
     with Segs[I] do
     begin
       mSz.X:=Points[I].X-Points[J].X;
       mSz.Y:=Points[I].Y-Points[J].Y;
       mDist:=GR32_Math.Hypot(mSz.X, mSz.Y);
       if (mDist > EPSILON) then
       begin
        R := 1 / mDist;
        mSz.X := mSz.X * R;
        mSz.Y := mSz.Y * R;
       end;
       PathLen:=PathLen+mDist;
     end;
     J:=I;
  end;

  if Len > 0 then
  begin
     SetLength(Dashs,Length(DashArray));
     if not Closed then
        PathLen:=PathLen- Segs[0].mDist;
     R:=PathLen/Len;
     for I := 0 to High(Dashs) do
       Dashs[I] := DashArray[I]*R;
     DashOffset:=DashOffset*R;
  end else
    Dashs:= DashArray;

  J := 0;
  // note to self: second dimension might not be zero by default!
  SetLength(Result, 1, 0);

  if not Odd(DashIndex) then
    AddPoint(Points[0].X, Points[0].Y);
  for I := 1 to High(Points) do
    AddDash(I);

  if Closed then
  begin
    AddDash(0);
    len1 := Length(Result[0]);
    len2 := Length(Result[J]);
    if (len1 > 0) and (len2 > 0) then
    begin
      SetLength(Result[0], len1 + len2 -1);
      Move(Result[0][0], Result[0][len2 - 1], SizeOf(TFloatPoint) * len1);
      Move(Result[J][0], Result[0][0], SizeOf(TFloatPoint) * len2);
      SetLength(Result, J);
      Dec(J);
    end;
  end;

  if (J >= 0) and (Length(Result[J]) = 0) then SetLength(Result, J);
end;

function BuildLineEnd(const P, N: TFloatPoint; const W: TFloat;
  EndStyle: TEndStyle): TArrayOfFloatPoint; overload;
var
  a1, a2: TFloat;
begin
  case EndStyle of
    esButt:
      begin
        Result := nil;
      end;
    esSquare:
      begin
        SetLength(Result, 2);
        Result[0].X := P.X + (N.X - N.Y) * W;
        Result[0].Y := P.Y + (N.Y + N.X) * W;
        Result[1].X := P.X - (N.X + N.Y) * W;
        Result[1].Y := P.Y - (N.Y - N.X) * W;
      end;
    esRound:
      begin
        a1 := ArcTan2(N.Y, N.X);
        a2 := ArcTan2(-N.Y, -N.X);
        if a2 < a1 then a2 := a2 + TWOPI;
        Result := BuildArc(P, a1, a2, W);
      end;
  end;
end;

function Grow(const Points: TArrayOfFloatPoint; const Normals: TArrayOfFloatPoint;
  const Delta: TFloat; JoinStyle: TJoinStyle; Closed: Boolean; MiterLimit: TFloat): TArrayOfFloatPoint; overload;
const
  BUFFSIZEINCREMENT = 128;
  MINDISTPIXEL = 1.414; // just a little bit smaller than sqrt(2),
  // -> set to about 2.5 for a similar output with the previous version
var
  I, L, H: Integer;
  ResSize, BuffSize: Integer;
  PX, PY: TFloat;
  AngleInv, RMin: TFloat;
  A, B, Dm: TFloatPoint;

  procedure AddPoint(const LongDeltaX, LongDeltaY: TFloat);
  begin
    if ResSize = BuffSize then
    begin
      Inc(BuffSize, BUFFSIZEINCREMENT);
      SetLength(Result, BuffSize);
    end;
    Result[ResSize] := FloatPoint(PX + LongDeltaX, PY + LongDeltaY);
    Inc(ResSize);
  end;

  procedure AddMitered(const X1, Y1, X2, Y2: TFloat);
  var
    R, CX, CY: TFloat;
  begin
    CX := X1 + X2;
    CY := Y1 + Y2;
    R := X1 * CX + Y1 * CY; //(1 - cos(ß))  (range: 0 <= R <= 2)
    if (R < RMin) then
    begin
      AddPoint(Delta * X1, Delta * Y1);
      AddPoint(Delta * X2, Delta * Y2);
    end else begin
      R := Delta / R;
      AddPoint(CX * R, CY * R);
    end;
  end;

  procedure AddBevelled(const X1, Y1, X2, Y2: TFloat);
  begin
      AddPoint(Delta * X1, Delta * Y1);
      AddPoint(Delta * X2, Delta * Y2);
  end;

  procedure AddRoundedJoin(const X1, Y1, X2, Y2: TFloat);
  var
    sinA, cosA, A: TFloat;
    steps,ii: Integer;
    C: TFloatPoint;
  begin
    sinA := X1 * Y2 - X2 * Y1;
    cosA := X1 * X2 + Y1 * Y2;
    A := ArcTan2(sinA, cosA);
    steps := Round(Abs(A * AngleInv));

    if sinA < 0 then
      Dm.Y := -Abs(Dm.Y)
    else
      Dm.Y := Abs(Dm.Y);
    C.X := X1 * Delta;
    C.Y := Y1 * Delta;
    AddPoint(C.X, C.Y);
    for ii := 1 to steps - 1 do
    begin
      C := FloatPoint(
        C.X * Dm.X - C.Y * Dm.Y,
        C.Y * Dm.X + C.X * Dm.Y);
      AddPoint(C.X, C.Y);
    end;
  end;

  procedure AddJoin(const X, Y, X1, Y1, X2, Y2: TFloat);
  begin
    PX := X;
    PY := Y;
    if (X1 * Y2 - X2 * Y1) * Delta < 0  then  //concave ang
    begin
      AddPoint(Delta * X1, Delta * Y1);
      AddPoint(Delta * X2, Delta * Y2);
      Exit;
    end;
    case JoinStyle of
      jsMiter: AddMitered(A.X, A.Y, B.X, B.Y);
      jsBevel: AddBevelled(A.X, A.Y, B.X, B.Y);
    else
       AddRoundedJoin(A.X, A.Y, B.X, B.Y);
    end;
  end;

begin
  Result := nil;

  if Length(Points) <= 1 then Exit;
  RMin := 2 / Sqr(MiterLimit);

  H := High(Points) - Ord(not Closed);
  while (H >= 0) and (Normals[H].X = 0) and (Normals[H].Y = 0) do Dec(H);

{** all normals zeroed => Exit }
  if H < 0 then Exit;

  L := 0;
  while (Normals[L].X = 0) and (Normals[L].Y = 0) do Inc(L);

  if Closed then
    A := Normals[H]
  else
    A := Normals[L];

  ResSize := 0;
  BuffSize := BUFFSIZEINCREMENT;
  SetLength(Result, BuffSize);

  // prepare
  if JoinStyle in [jsRound, jsRoundEx] then
  begin
    Dm.X := 1 - 0.5 * Min(3, Sqr(MINDISTPIXEL / Abs(Delta)));
    Dm.Y := Sqrt(1 - Sqr(Dm.X));
    AngleInv := 1 / ArcCos(Dm.X);
  end;

  for I := L to H do
  begin
    B := Normals[I];
    if (B.X = 0) and (B.Y = 0) then Continue;
    with Points[I] do
      AddJoin(X, Y, A.X, A.Y, B.X, B.Y);
    A := B;
  end;
  if not Closed then
    with Points[High(Points)] do AddJoin(X, Y, A.X, A.Y, A.X, A.Y);
  SetLength(Result, ResSize);
end;
function BuildPolyline(const Points: TArrayOfFloatPoint; StrokeWidth: TFloat;
  JoinStyle: TJoinStyle; EndStyle: TEndStyle; MiterLimit: TFloat): TArrayOfFloatPoint;
var
  L, H: Integer;
  Normals: TArrayOfFloatPoint;
  P1, P2, E1, E2: TArrayOfFloatPoint;
  V: TFloat;
  P: PFloatPoint;
  Pt1,Pt2:TFloatPoint;
begin
  Result := nil;
  V := StrokeWidth * 0.5;
  H := High(Points) - 1;
  if (H=0) then
  begin
     Pt1:=Points[0];
     Pt2:=Points[1];
     if (Pt1.X=Pt2.X)and(Pt1.Y=Pt2.Y) then
     begin
       E1 := BuildLineEnd(Pt1, FloatPoint(0,1), -V, EndStyle);
       E2 := BuildLineEnd(Pt2, FloatPoint(0,1), V, EndStyle);

        SetLength(Result, Length(E1) + Length(E2));
        P := @Result[0];
        Move(E1[0], P^, Length(E1) * SizeOf(TFloatPoint));
        Inc(P, Length(E1));
        Move(E2[0], P^, Length(E2) * SizeOf(TFloatPoint));
       Exit;
     end;
  end;

  Normals := BuildNormals(Points);


  while (H >= 0) and (Normals[H].X = 0) and (Normals[H].Y = 0) do Dec(H);
  if H < 0 then Exit;
  L := 0;
  while (Normals[L].X = 0) and (Normals[L].Y = 0) do Inc(L);

  P1 := UPolylines.Grow(Points, Normals, V, JoinStyle, False, MiterLimit);
  P2 := ReversePolygon(UPolylines.Grow(Points, Normals, -V, JoinStyle, False, MiterLimit));

  E1 := BuildLineEnd(Points[0], Normals[L], -V, EndStyle);

   E2 := BuildLineEnd(Points[High(Points)], Normals[H], V, EndStyle);

  SetLength(Result, Length(P1) + Length(P2) + Length(E1) + Length(E2));
  P := @Result[0];
  Move(E1[0], P^, Length(E1) * SizeOf(TFloatPoint)); Inc(P, Length(E1));
  Move(P1[0], P^, Length(P1) * SizeOf(TFloatPoint)); Inc(P, Length(P1));
  Move(E2[0], P^, Length(E2) * SizeOf(TFloatPoint)); Inc(P, Length(E2));
  Move(P2[0], P^, Length(P2) * SizeOf(TFloatPoint));
end;

function SVGBuildPolyPolyLine(const Points: TArrayOfArrayOfFloatPoint;
  StrokeWidth: TFloat; JoinStyle: TJoinStyle;
  EndStyle: TEndStyle; MiterLimit: TFloat): TArrayOfArrayOfFloatPoint;
var
  Closed: Boolean;
  I,Len,Cap,L: Integer;
  P1, P2,t: TArrayOfFloatPoint;
  Normals: TArrayOfFloatPoint;
  t1,t2:TFloatpoint;
  procedure Add(const V:TArrayOfFloatPoint);
  begin
      if Cap=Len then
      begin
         Cap:=Cap+64;
         Setlength(Result,Cap);
      end;
      Result[len]:=v;
      inc(len);
  end;
begin
  Cap:=0;
  Len:=0;
  for I := 0 to High(Points) do
  begin
    t:=Points[I];
    L:=Length(t);
    if L<2 then
       continue;
    t1:=t[0];
    t2:=t[L-1];
    Closed:=(L>2)and(t1.X=t2.X)and(t1.Y=t2.Y);
    if Closed then
    begin
      Normals := BuildNormals(t);
      P1 := UPolylines.Grow(t, Normals, StrokeWidth * 0.5, JoinStyle, True, MiterLimit);
      P2 := UPolylines.Grow(t, Normals, -StrokeWidth * 0.5, JoinStyle, True, MiterLimit);
      Add(P1);
      Add(ReversePolygon(P2));
    end else
         Add(BuildPolyline(t, StrokeWidth, JoinStyle, EndStyle,MiterLimit));
  end;
  Setlength(Result,Len);
end;
end.
