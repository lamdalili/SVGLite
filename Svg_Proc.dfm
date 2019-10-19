object Form1: TForm1
  Left = 198
  Top = 158
  AlphaBlendValue = 180
  Caption = 'Form1'
  ClientHeight = 337
  ClientWidth = 680
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object ImgView: TImgView32
    Left = 0
    Top = 49
    Width = 680
    Height = 288
    Align = alClient
    Bitmap.ResamplerClassName = 'TNearestResampler'
    BitmapAlign = baCustom
    Centered = False
    Color = clWhite
    ParentColor = False
    Scale = 1.000000000000000000
    ScaleMode = smScale
    ScrollBars.ShowHandleGrip = True
    ScrollBars.Style = rbsDefault
    ScrollBars.Size = 17
    OverSize = 0
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 680
    Height = 49
    Align = alTop
    TabOrder = 1
    object Open: TButton
      Left = 15
      Top = 10
      Width = 75
      Height = 25
      Caption = 'Open'
      TabOrder = 0
      OnClick = OpenClick
    end
    object BPNGSave: TButton
      Left = 260
      Top = 10
      Width = 75
      Height = 25
      Caption = 'Export'
      TabOrder = 1
      OnClick = BPNGSaveClick
    end
    object CUseAlpha: TCheckBox
      Left = 341
      Top = 15
      Width = 97
      Height = 15
      Caption = 'export alpha'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
  end
end
