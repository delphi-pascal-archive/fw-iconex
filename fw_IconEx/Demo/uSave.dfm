object dlgSave: TdlgSave
  Left = 357
  Top = 259
  BorderStyle = bsToolWindow
  Caption = #1057#1086#1093#1088#1072#1085#1077#1085#1080#1077' '#1080#1082#1086#1085#1082#1080
  ClientHeight = 270
  ClientWidth = 312
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object btnSave: TButton
    Left = 154
    Top = 240
    Width = 75
    Height = 25
    Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object btnCancel: TButton
    Left = 235
    Top = 240
    Width = 75
    Height = 25
    Cancel = True
    Caption = #1054#1090#1084#1077#1085#1072
    ModalResult = 2
    TabOrder = 1
  end
  object GroupBox1: TGroupBox
    Left = 0
    Top = 0
    Width = 312
    Height = 234
    Align = alTop
    Caption = #1059#1082#1072#1078#1080#1090#1077' '#1082#1072#1082#1080#1077' '#1092#1086#1088#1084#1072#1090#1099' '#1085#1077#1086#1073#1093#1086#1076#1080#1084#1086' '#1089#1086#1093#1088#1072#1085#1103#1090#1100':'
    TabOrder = 2
    object lbFormats: TCheckListBox
      Left = 2
      Top = 15
      Width = 308
      Height = 217
      Align = alClient
      ItemHeight = 13
      TabOrder = 0
    end
  end
end
