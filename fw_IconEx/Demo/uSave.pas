unit uSave;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, CheckLst;

type
  TdlgSave = class(TForm)
    lbFormats: TCheckListBox;
    btnSave: TButton;
    btnCancel: TButton;
    GroupBox1: TGroupBox;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dlgSave: TdlgSave;

implementation

{$R *.dfm}

end.
