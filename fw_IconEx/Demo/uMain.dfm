object Form21: TForm21
  Left = 222
  Top = 127
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'fwIconEx'
  ClientHeight = 425
  ClientWidth = 762
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 17
  object GroupBox1: TGroupBox
    Left = 10
    Top = 10
    Width = 368
    Height = 373
    Caption = ' FWIconEx '
    TabOrder = 0
    object FWIconEx1: TFWIconEx
      Left = 2
      Top = 19
      Width = 359
      Height = 352
      Align = alLeft
    end
  end
  object GroupBox2: TGroupBox
    Left = 386
    Top = 10
    Width = 367
    Height = 373
    Caption = ' '#1057#1090#1072#1085#1076#1088#1072#1090#1085#1099#1081' TImage '
    TabOrder = 1
    object Image1: TImage
      Left = 10
      Top = 21
      Width = 351
      Height = 348
    end
  end
  object TrackBar1: TTrackBar
    Left = 10
    Top = 391
    Width = 368
    Height = 26
    TabOrder = 2
    ThumbLength = 14
    OnChange = TrackBar1Change
  end
  object Button1: TButton
    Left = 387
    Top = 392
    Width = 190
    Height = 25
    Caption = #1042#1099#1073#1088#1072#1090#1100' '#1080#1082#1086#1085#1082#1091'...'
    TabOrder = 3
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 585
    Top = 392
    Width = 168
    Height = 25
    Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1080#1082#1086#1085#1082#1091'...'
    TabOrder = 4
    OnClick = Button2Click
  end
  object OpenPictureDialog1: TOpenPictureDialog
    Filter = 'Icons (*.ico)|*.ico'
    Left = 312
    Top = 240
  end
  object SavePictureDialog1: TSavePictureDialog
    DefaultExt = 'ico'
    Filter = 'Icons (*.ico)|*.ico'
    Left = 344
    Top = 240
  end
end
