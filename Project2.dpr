program Project2;

uses
  Forms,
  Svg_Proc in 'Svg_Proc.pas' {Form1},
  USVG in 'USVG.pas',
  USVGStack in 'USVGStack.pas',
  USVGGraphics32 in 'USVGGraphics32.pas',
  UTxtToPath in 'UTxtToPath.pas',
  UPolylines in 'UPolylines.pas',
  GdiPng in 'GdiPng.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
