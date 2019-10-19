unit UMatrix;

interface

type
  TMatrix = record
     A: array [0..2,0..2] of Single;
  end;
  PMatrix =^TMatrix;

  function MulMx(const M1, M2: TMatrix): TMatrix;
  function TransMx(const tx,ty:Extended):TMatrix;
  function RotMx(const ang:Extended):TMatrix;
  function ScaleMx(const sx,sy:Extended):TMatrix;
  procedure FillMx(const a,b,c,d,e,f:Extended;var M:TMatrix);
  procedure TransFormVal(const Mx:TMatrix;const ax, ay: Extended; var Xo,Yo: Extended );

const
  IdentityMatrix: TMatrix=(A:((1.0,0.0,0.0),(0.0,1.0,0.0),(0.0,0.0,1.0)));
implementation
uses Sysutils,math;

procedure TransFormVal(const Mx:TMatrix;const ax, ay: Extended; var Xo,Yo: Extended );
begin
  with Mx do
  begin
     Xo := (A[0, 0] * ax + A[1, 0] * ay) + A[2, 0];
     Yo := (A[0, 1] * ax + A[1, 1] * ay) + A[2, 1];
  end;
end;

function TransMx(const tx,ty:Extended):TMatrix;
begin
  Result := IdentityMatrix;
  Result.A[2, 0] := tx;
  Result.A[2, 1] := ty;
end;

function RotMx(const ang:Extended):TMatrix;
var
  S, C: Extended;
begin
  SinCos(ang, S, C);
  Result := IdentityMatrix;
  Result.A[0, 0] := C;
  Result.A[1, 0] := S;
  Result.A[0, 1] := -S;
  Result.A[1, 1] := C;
end;

function ScaleMx(const sx,sy:Extended):TMatrix;
begin
  Result := IdentityMatrix;
  Result.A[0, 0] := sx;
  Result.A[1, 1] := sy;
end;
procedure FillMx(const a,b,c,d,e,f:Extended;var M:TMatrix);
begin
  M.A[0, 0] := a;
  M.A[0, 1] := b;
  M.A[1, 0] := c;
  M.A[1, 1] := d;
  M.A[2, 0] := e;
  M.A[2, 1] := f;
  M.A[0, 2] := 0;
  M.A[1, 2] := 0;
  M.A[2, 2] := 1;
end;

function MulMx(const M1, M2: TMatrix): TMatrix;
var
  I, J: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
      Result.A[I, J] :=
        M1.A[0, J] * M2.A[I, 0] +
        M1.A[1, J] * M2.A[I, 1] +
        M1.A[2, J] * M2.A[I, 2];
end;

end.
