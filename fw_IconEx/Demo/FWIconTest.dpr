program FWIconTest;

uses
  Forms,
  uMain in 'uMain.pas' {Form21},
  uSave in 'uSave.pas' {dlgSave};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm21, Form21);
  Application.CreateForm(TdlgSave, dlgSave);
  Application.Run;
end.
