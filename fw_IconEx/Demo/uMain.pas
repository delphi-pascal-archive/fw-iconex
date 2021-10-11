unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ComCtrls, StdCtrls, FWIconEx, ExtDlgs;

type
  TForm21 = class(TForm)
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    TrackBar1: TTrackBar;
    FWIconEx1: TFWIconEx;
    Image1: TImage;
    Button1: TButton;
    OpenPictureDialog1: TOpenPictureDialog;
    Button2: TButton;
    SavePictureDialog1: TSavePictureDialog;
    procedure Button2Click(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  end;

var
  Form21: TForm21;

implementation

{$R *.dfm}

uses
  uSave;

procedure TForm21.Button2Click(Sender: TObject);
var
  I: Byte;
  Formats: TFWIconExFormatSet;
begin
  dlgSave := TdlgSave.Create(nil);
  try
    for I := 0 to FWIconEx1.FormatCount - 1 do
    begin
      dlgSave.lbFormats.Items.Add(
        Format(' FWIconEx: %dx%d, глубина цвета %d ',
          [
            FWIconEx1.IconFormats[I].bWidth,
            FWIconEx1.IconFormats[I].bHeight,
            FWIconEx1.IconFormats[I].wBitCount
          ]));
      dlgSave.lbFormats.Checked[I] := True;
    end;
    if dlgSave.ShowModal = mrOk then
    begin
      Formats := [];
      for I := 0 to FWIconEx1.FormatCount - 1 do
        if dlgSave.lbFormats.Checked[I] then
          Include(Formats, I);
      if SavePictureDialog1.Execute then
        FWIconEx1.SaveToFile(SavePictureDialog1.FileName, Formats);
    end;
  finally
    dlgSave.Release;
  end;
  
end;

procedure TForm21.FormCreate(Sender: TObject);
begin
  FWIconEx1.Icon.LoadFromFile('Office.ico');
  Image1.Picture.Icon.Assign(FWIconEx1.Icon);
  GroupBox1.DoubleBuffered := True;
  TrackBar1.Max := FWIconEx1.FormatCount - 1;
  TrackBar1.Position := FWIconEx1.CurrentFormat;
end;

procedure TForm21.TrackBar1Change(Sender: TObject);
begin
  FWIconEx1.CurrentFormat := TrackBar1.Position;
  GroupBox1.Caption := Format(' FWIconEx: %dx%d, глубина цвета %d ',
    [
      FWIconEx1.IconFormats[FWIconEx1.CurrentFormat].bWidth,
      FWIconEx1.IconFormats[FWIconEx1.CurrentFormat].bHeight,
      FWIconEx1.IconFormats[FWIconEx1.CurrentFormat].wBitCount
    ]);
end;

procedure TForm21.Button1Click(Sender: TObject);
begin
  if OpenPictureDialog1.Execute then
  begin
    FWIconEx1.Icon.LoadFromFile(OpenPictureDialog1.FileName);
    Image1.Picture.Icon.Assign(FWIconEx1.Icon);
    TrackBar1.Max := FWIconEx1.FormatCount - 1;
    TrackBar1.Position := FWIconEx1.CurrentFormat;
  end;
end;

end.
