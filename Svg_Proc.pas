unit Svg_Proc;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,USVG,USVGGraphics32, GR32, GR32_Image,ExtCtrls;
type
  TForm1 = class(TForm)
    Open: TButton;
    ImgView: TImgView32;
    Panel1: TPanel;
    CUseAlpha: TCheckBox;
    BPNGSave: TButton;
    procedure OpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BPNGSaveClick(Sender: TObject);
  private
    { Déclarations privées }
  public

  end;

var
  Form1: TForm1;

implementation
uses GdiPng;
{$R *.dfm}

procedure TForm1.OpenClick(Sender: TObject);
var
 Doc:TSVGLoader;
 S:string;
begin
 if not PromptForfilename(s,'*.svg|*.svg','.svg') then
    Exit;
 Doc:=TSVGLoader.Create(ImgView.Bitmap );
 ImgView.Bitmap.BeginUpdate;
 try
   Doc.LoadFromFile(S);
 finally
   ImgView.Bitmap.EndUpdate;
 end;
 Doc.Free;
 ImgView.Refresh;
end;

procedure TForm1.BPNGSaveClick(Sender: TObject);
var
  S:string;
  FS:TFilestream;
begin
  if not PromptForFilename(S,'png|*.png','.png','','',True) then
     Exit;
  FS:=TFilestream.Create(S,fmCreate);
  try
     Bitmap32ToPNGStream(ImgView.Bitmap,FS,CuseAlpha.Checked);
  finally
     FS.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ImgView.SetupBitmap(True,Color32(ImgView.Color));
end;

end.
