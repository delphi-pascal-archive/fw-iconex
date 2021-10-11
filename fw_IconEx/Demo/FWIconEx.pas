////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Unit Name : FWIconEx
//  * Purpose   : Класс для отображения изображения иконки
//  *           : в любом формате, присутствующем в самой иконке.
//  * Author    : Александр (Rouse_) Багель
//  * Editor    : n0wheremany
//  * Copyright : © Fangorn Wizards Lab 1998 - 2007
//  * Version   : 1.03
//  * Home Page : http://rouse.drkb.ru
//  * Home Page : http://nowhere.org.ua
//  ****************************************************************************

unit FWIconEx;

interface

  {$DEFINE USE_ASM}

uses
  Windows,
  Messages,
  SysUtils,
  Classes,
  Controls,
  Graphics;

type
  PIconDirectoryEntry = ^TIconDirectoryEntry;
  TIconDirectoryEntry = packed record
    bWidth: Byte;
    bHeight: Byte;
    wColorCount: Word;
    wPlanes: Word;
    wBitCount: Word;
    dwBytesInRes: DWORD;
    dwImageOffset: DWORD;
  end;

  TFWIconExFormatSet = set of Byte;

  TFWCustomIconEx = class(TGraphicControl)
  private
    FIconDir: TCursorOrIcon;
    FIconDirectoryEntry: array of TIconDirectoryEntry;
    FAlphaBitmap: TBitmap;
    ColorTable: array of Byte;
    FCurrentBitmapInfo: PBitmapInfoHeader;
    FPropertyIcon: TIcon;
    FCurrentFormat: Integer;
    FOnMouseLeave : TNotifyEvent;
    FOnMouseEnter : TNotifyEvent;
    procedure SetCurrentFormat(const Value: Integer);
    function GetFormatCount: Integer;
    function GetIconFormat(Index: Integer): TIconDirectoryEntry;
    procedure SetIcon(const Value: TIcon);
  protected
    procedure EmptyIconInfo; virtual;
    function GetBitmapInfo(const Format: Integer): PBitmapInfoHeader;
    procedure GetDIBBitmapEx(var BI: TBitmapInfoHeader; const ACanvas: TCanvas;
      P: TPoint); virtual;
    procedure OnIconChange(Sender: TObject); virtual;
    procedure UpdateIconInfo; virtual;
    procedure Paint; override;
    procedure CMMouseEnter(var AMsg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var AMsg: TMessage); message CM_MOUSELEAVE;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure ShowBestFormat; virtual;
    procedure SaveToFile(const FileName: String; Formats: TFWIconExFormatSet);
    procedure SaveToStream(Stream: TStream; Formats: TFWIconExFormatSet);
    property FormatCount: Integer read GetFormatCount;
    property IconFormats[Index: Integer]: TIconDirectoryEntry read
      GetIconFormat;
  published
    property Icon: TIcon read FPropertyIcon write SetIcon;
    property CurrentFormat: Integer read FCurrentFormat write SetCurrentFormat default -1;
    property OnMouseLeave:TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
    property OnMouseEnter:TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
  end;

  TFWIconEx = class(TFWCustomIconEx)
  published
    property Align;
    property Anchors;
    property AutoSize;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseLeave;
    property OnMouseEnter;
    property OnMouseUp;
    property OnStartDock;
    property OnStartDrag;
  end;

implementation

uses
  Consts,
  RTLConsts;

procedure OutOfResources;
begin
  raise EOutOfResources.Create(SOutOfResources);
end;

procedure GDIError;
var
  ErrorCode: Integer;
  Buf: array [Byte] of Char;
begin
  ErrorCode := GetLastError;
  if (ErrorCode <> 0) and (FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, nil,
    ErrorCode, LOCALE_USER_DEFAULT, Buf, sizeof(Buf), nil) <> 0) then
    raise EOutOfResources.Create(Buf)
  else
    OutOfResources;
end;

{$IFNDEF USE_ASM}

//  Смешение двух растров с использованием информации о альфа канале
//  достаточно медленный вариант, использовать не желательно.
//  Если все-же решите использовать именно его, то для этого необходимо
//  закоментировать директиву компилятора {$DEFINE USE_ASM} обьявленную в начале модуля
// =============================================================================
procedure MakeAlphaBlend(DIBColorSrc, DIBDest: PRGBQuad;
  const DIBColorSrcSize: Integer);  
var
  I: Integer;
begin
  for I := 0 to (DIBColorSrcSize shr 2) - 1 do
  begin
    if DIBColorSrc^.rgbReserved = 255 then
      DIBDest^ := DIBColorSrc^
    else
      if DIBColorSrc^.rgbReserved > 0 then
      begin
        DIBDest^.rgbBlue := Byte(MulDiv(DIBColorSrc^.rgbBlue,
          DIBColorSrc^.rgbReserved, 255)
          + MulDiv(DIBDest^.rgbBlue, 255 - DIBColorSrc^.rgbReserved, 255));
        DIBDest^.rgbGreen := Byte(MulDiv(DIBColorSrc^.rgbGreen,
          DIBColorSrc^.rgbReserved, 255)
          + MulDiv(DIBDest^.rgbGreen, 255 - DIBColorSrc^.rgbReserved, 255));
        DIBDest^.rgbRed := Byte(MulDiv(DIBColorSrc^.rgbRed,
          DIBColorSrc^.rgbReserved, 255)
          + MulDiv(DIBDest^.rgbRed, 255 - DIBColorSrc^.rgbReserved, 255));
      end;
    Inc(DIBDest);
    Inc(DIBColorSrc);
  end;
end;

{$ELSE}

//  Смешение двух растров с использованием информации о альфа канале
//  Оптимизированный по скорости вариант
// =============================================================================
procedure MakeAlphaBlend(DIBColorSrc, DIBDest: PRGBQuad;
  const DIBColorSrcSize: Integer); assembler;
asm

  // Запоминаем значение регистров в стеке

  push eax
  push ebx
  push ecx
  push edx
  push edi
  push esi

  mov  esi, DIBColorSrc       // карта цветов иконки
  mov  edi, DIBDest           // карта цветов фона
  //mov  ecx, DIBColorSrcSize   // размер массивов (приходит в ECX сам по себе)

  shr  ecx, 2                 // размер элемента массива равен четырем,
                              // поэтому поправим счетчик цикла

// -----------------------------------------------------------------------------

@loop:

  // цвета представленны следующим образом
  // [esi]  = синий
  // [esi + 1]  = зеленый
  // [esi + 2] = красный
  // [esi + 3]  = альфа канал

  mov  al, [esi + 3]          // читаем значение альфа канала
  cmp  al, 0                  // есть ли изображение иконки в данном пикселе?
  jne  @paint_full

  add  esi, 4                 // если нет - берем следующий элемент
  add  edi, 4
  loop @loop
  jmp  @done

// -----------------------------------------------------------------------------

@paint_full:
  cmp  al, 255                // Смотрим интенсивность цвета
  jne  @paint_alpha

  mov  eax, [esi]             // Данный пиксель полностью заполнен цветом иконки
  mov  [edi], eax             // копируем его целиком

  add  esi, 4                 // берем следующий элемент
  add  edi, 4
  loop @loop
  jmp  @done

// -----------------------------------------------------------------------------

@paint_alpha:

  // присутствует альфаканал
  
  xor  ebx, ebx
  call @make_alpha            // микшируем синий цвет
  inc  ebx
  call @make_alpha            // микшируем зеленый цвет
  inc  ebx
  call @make_alpha            // микшируем красный цвет

  add  esi, 4                 // берем следующий элемент
  add  edi, 4
  loop @loop
  jmp  @done

// -----------------------------------------------------------------------------

@make_alpha:

  // функция смешивает два цвета в зависимости от значения EBX,
  // которое указывает какой именно брать байт из RGB

  xor  eax, eax
  xor  edx, edx
  mov  al, byte [edi + ebx]   // берем цвет приемника
  mov  dl, byte [esi + 3]     // берем значение альфаканала
  not  dl                     // значение альфаканала вычитаем из 255
  mul  dl                     // умножаем на получившееся значение
  or   dl, $FF
  div  dl                     // делим на 255

  mov  byte [edi + ebx], al   // запоминаем первый результат

  xor  eax, eax
  xor  edx, edx
  mov  al, byte [esi + ebx]   // берем цвет источника
  mov  dl, byte [esi + 3]     // берем значение альфаканала
  mul  dl                     // умножаем на значение альфаканала
  or   dl, $FF
  div  dl                     // делим на 255

  xor  edx, edx
  mov  dl, byte [edi + ebx]   // читаем первый результат
  add  ax, dx                 // к нему прибавляем второй результат
  mov  byte [edi + ebx], al   // сумму помещаем обратно

  ret

// -----------------------------------------------------------------------------  

@done:

  // Восстановление значений регистров из стека
  
  pop  esi
  pop  edi
  pop  edx
  pop  ecx
  pop  ebx
  pop  eax
end;

{$ENDIF}

//  Создание битмапа из иконки и вывод его на канвас
// =============================================================================
procedure TFWCustomIconEx.GetDIBBitmapEx(var BI: TBitmapInfoHeader;
  const ACanvas: TCanvas; P: TPoint);

  function GDICheck(Value: Integer): Integer;
  begin
    if Value = 0 then GDIError;
    Result := Value;
  end;

type
  PLongArray = ^TLongArray;
  TLongArray = array[0..1] of Longint;
var
  I, A, C, nNumColors: Integer;
  pColorTable, pDIBColor, pDIBMask: Pointer;
  nColorTableSize, nDIBColorSize{, nDIBMaskSize}: DWORD;
  hDIBColor, hDIBMask: HBITMAP;
  pColorBuffer, pMaskBuffer: Pointer;
  hdcColor, hdcMask, hdcTempColor, hdcTempMask, DC: HDC;
  Colors: PLongArray;
  DestBits: array[0..$FFFF] of TRGBQuad;
  //pDestBits: Pointer;
  pRGB{, RGBQuad}: PRGBQuad;
begin

  // ЭТАП 1: Подготовка...

  // Преобразуем данные для последующей обработки
  with BI do
  begin
    biHeight := biHeight shr 1; // Высота включает высоту маски
    biSizeImage := BytesPerScanline(biWidth, biBitCount, 32) * biHeight;
    case biBitCount of
      1, 4, 8, 16: nNumColors := 1 shl biBitCount;
    else
      nNumColors := 0;
    end;
  end;
  try

    // Рассчитываем размеры таблицы цветов, растра цветов и растра маски
    nColorTableSize := nNumColors * SizeOf(TRGBQuad);
    nDIBColorSize := (((BI.biWidth * BI.biBitCount + 31) shr 5) * BI.biHeight) shl 2;
    //nDIBMaskSize := (((BI.biWidth + 31) shr 5)* BI.biHeight) shl 2;

    // Получаем указатели на таблицу цветов, растр цветов и растр маски
    pColorTable := Pointer(DWORD(@BI) + SizeOf(BI));
    pDIBColor := Pointer(DWORD(pColorTable) + nColorTableSize);
    pDIBMask :=  Pointer(DWORD(pDIBColor) + nDIBColorSize);

    // ЭТАП 2: Альфаканал

    // Если иконка с альфаканалом,
    // то отрисовкой придется заниматься самостоятельно.
    // Ибо DrawIconEx в Windows 9х/Ме не отобразит альфа-канал,
    // а AlphaBlend из msimg32.dll будет выводить иконку
    // с заметными артефактами изображения.
    if BI.biBitCount = 32 then
    begin

      //pDestBits := @DestBits[0];

      // Зададим размеры временного битмапа в соответствии
      // с размерами иконки

      FAlphaBitmap.Width := BI.biWidth;
      FAlphaBitmap.Height := BI.biHeight;
      FAlphaBitmap.PixelFormat := pf32bit;

      // Скопируем область экрана, куда будет выведено изображение
      BitBlt(FAlphaBitmap.Canvas.Handle, 0, 0, BI.biWidth, BI.biHeight,
        ACanvas.Handle, P.X, P.Y, SRCCOPY);

      // Помещаем карту цвета изображения в массив, для последующей обработки
	    // Изменения от n0wheremany
      // поправлена работа с нестандартными размерами иконки	  
      C := 0;
      for I := BI.biHeight - 1 downto 0 do
      begin
        pRGB := FAlphaBitmap.ScanLine[I];
        //C := ((BI.biHeight - 1) - I) * BI.biHeight; // BUG FIX
        for A := 0 to BI.biWidth - 1 do
        begin
          //DestBits[A+C] := pRGB^; // BUG FIX
          DestBits[C] := pRGB^;
          Inc(pRGB);
          Inc(C)
        end;
      end;
      // Накладываем изображение иконки на канвас, с учетом альфа канала
      MakeAlphaBlend(PRGBQuad(pDIBColor),
        PRGBQuad(@DestBits[0]), nDIBColorSize);

      // Модифицированную карту цвета помещаем обратно на канвас
      C := 0;
      for I := BI.biHeight - 1 downto 0 do
      begin
        pRGB := FAlphaBitmap.ScanLine[I];
        //C := ((BI.biHeight - 1) - I) * BI.biHeight; // BUG FIX
        for A := 0 to BI.biWidth - 1 do
        begin
          //pRGB^ := DestBits[C + A]; // BUG FIX
          pRGB^ := DestBits[C];
          Inc(pRGB);
          Inc(c);
        end;
      end;

      // Выводим результат
      BitBlt(ACanvas.Handle, P.X, P.Y, BI.biWidth, BI.biHeight,
        FAlphaBitmap.Canvas.Handle, 0, 0, SRCCOPY);

      Exit;
    end;

    // ЭТАП 3: Отрисовка

    // Если альфа канал отсутствует, то создадим битмап из
    // растра цветов и растра маски иконки
    DC := GetDC(0);
    if DC = 0 then OutOfResources;
    try
      pColorBuffer := nil;
      // Создаем DIB секцию для растра цветов
      hDIBColor := GDICheck(CreateDIBSection(DC, PBitmapInfo(@BI)^,
        DIB_RGB_COLORS, pColorBuffer, 0, 0));
      try
        // Создаем контекст устройства памяти
        hdcColor := GDICheck(CreateCompatibleDC(DC));
        try
          // Назначаем контексту объект (DIB секцию)
          hdcTempColor := SelectObject(hdcColor, hDIBColor);
          try
            SetBkColor(hdcColor, RGB(1, 1, 1));
            // Копируем растр цвета
            SetDIBitsToDevice(hdcColor, 0, 0, BI.biWidth, BI.biHeight, 0,
              0, 0, BI.biHeight, pDIBColor, PBitmapInfo(@BI)^, DIB_RGB_COLORS);

            // Модифицируем BitmapInfoHeader для работы с растром маски
            with BI do
            begin
              biBitCount := 1;
              biSizeImage := BytesPerScanline(biWidth, biBitCount, 32) * biHeight;
              biClrUsed := 2;
              biClrImportant := 2;
            end;
            Colors := Pointer(DWORD(@BI) + SizeOf(BI));
            Colors^[0] := 0;
            Colors^[1] := $FFFFFF;

            // Создаем DIB секцию для растра маски
            pMaskBuffer := nil;
            hDIBMask := GDICheck(CreateDIBSection(0, PBitmapInfo(@BI)^,
              DIB_RGB_COLORS, pMaskBuffer, 0, 0));
            try
              // Создаем контекст устройства памяти
              hdcMask := GDICheck(CreateCompatibleDC(0));
              try
                // Назначаем контексту объект (DIB секцию маски)
                hdcTempMask := SelectObject(hdcMask, hDIBMask);
                try
                  // Копируем растр маски
                  SetDIBitsToDevice (hdcMask, 0, 0, BI.biWidth, BI.biHeight, 0,
                    0, 0, BI.biHeight, pDIBMask, PBitmapInfo(@BI)^, DIB_RGB_COLORS);

                  // Выводим маску на переданный канвас
                  BitBlt(ACanvas.Handle, P.X, P.Y, BI.biWidth, BI.biHeight,
                    hdcMask, 0, 0, SRCAND);
                finally
                  SelectObject(hdcMask, hdcTempMask);
                end;
              finally
                DeleteObject(hdcMask);
              end;
            finally
              DeleteObject(hDIBMask);
            end;
            // Инвертируем поверх маски цветовой растр
            BitBlt(ACanvas.Handle, P.X, P.Y, BI.biWidth, BI.biHeight,
              hdcColor, 0, 0, SRCINVERT);
          finally
            SelectObject(hdcColor, hdcTempColor);
          end;
        finally
          DeleteObject(hdcColor);
        end;
      finally
        DeleteObject(hDIBColor);
      end;
    finally
      ReleaseDC(0, DC);
    end;
  finally
    BI.biHeight := BI.biHeight shl 1;
  end;
end;

{ TFWCustomIconEx }

//  Собственно создание компонента...
// =============================================================================
constructor TFWCustomIconEx.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle - [csOpaque];
  FPropertyIcon := TIcon.Create;
  FPropertyIcon.OnChange := OnIconChange;
  FAlphaBitmap := nil;
  Height := 105;
  Width := Height;
  EmptyIconInfo;
end;

//  ... и его разрушение
// =============================================================================
destructor TFWCustomIconEx.Destroy;
begin
  EmptyIconInfo;
  FPropertyIcon.Free;
  inherited;
end;

//  Очистка всех структур
// =============================================================================
procedure TFWCustomIconEx.EmptyIconInfo;
begin
  if FAlphaBitmap <> nil then
    FreeAndNil(FAlphaBitmap);
  FCurrentBitmapInfo := nil;
  ZeroMemory(@FIconDir, SizeOf(TCursorOrIcon));
  SetLength(FIconDirectoryEntry, 0);
  FCurrentFormat := -1;
end;

//  Выбор наиболее качественного формата иконки.
//  Прежде всего находиться самая большая глубина цвета,
//  после чего ищется иконка имеющая самое большое соотношение
//  ширины и высоты с данной глубиной цвета
// =============================================================================
procedure TFWCustomIconEx.ShowBestFormat;
var
  BestWithPerHeight, BestColorDepth, TmpBestWithPerHeight: DWORD;
  I, BestFormat: Integer;
begin
  BestFormat := -1;
  BestWithPerHeight := 0;
  BestColorDepth := 0;
  if FormatCount = 0 then
  begin
    CurrentFormat := -1;
    Exit;
  end;
  for I := 0 to FormatCount - 1 do
  begin
    TmpBestWithPerHeight := FIconDirectoryEntry[I].bWidth *
      FIconDirectoryEntry[I].bHeight;
    if FIconDirectoryEntry[I].wBitCount > BestColorDepth then
    begin
      BestColorDepth := FIconDirectoryEntry[I].wBitCount;
      BestWithPerHeight := TmpBestWithPerHeight;
      BestFormat := I;
    end;

    if (TmpBestWithPerHeight > BestWithPerHeight) then
      if FIconDirectoryEntry[I].wBitCount = BestColorDepth then
      begin
        BestWithPerHeight := TmpBestWithPerHeight;
        BestFormat := I;
      end;
  end;
  CurrentFormat := BestFormat;
end;


//  Получение указателя на структуру BitmapInfoHeader соответствующую
//  запрощенному формату
// =============================================================================
function TFWCustomIconEx.GetBitmapInfo(const Format: Integer): PBitmapInfoHeader;
var
  Stream: TMemoryStream;
begin
  Result := nil;

  if Format = -1 then Exit;
  
  if (Format < 0) or (Format >= FormatCount) then
    raise EListError.CreateResFmt(@SListIndexError, [Format]);

  Stream := TMemoryStream.Create;
  try
    FPropertyIcon.SaveToStream(Stream);
    Stream.Position := FIconDirectoryEntry[Format].dwImageOffset;
    SetLength(ColorTable, FIconDirectoryEntry[Format].dwBytesInRes);
    Stream.Read(ColorTable[0], FIconDirectoryEntry[Format].dwBytesInRes);
    Result := PBitmapInfoHeader(@ColorTable[0]);
  finally
    Stream.Free;
  end;
end;

//  Возвращает кол-во доступных форматов у иконки
// =============================================================================
function TFWCustomIconEx.GetFormatCount: Integer;
begin
  Result := FIconDir.Count;
end;

//  Возвращает структуру, описывающую формат иконки
// =============================================================================
function TFWCustomIconEx.GetIconFormat(Index: Integer): TIconDirectoryEntry;
begin
  if (Index < -1) or (Index >= FormatCount) then
    raise EListError.CreateResFmt(@SListIndexError, [Index]);
  Result := FIconDirectoryEntry[Index];
end;

//  Обновление информации о иконке
//  Читаются и заполняются соответствующие структуры
// =============================================================================
procedure TFWCustomIconEx.UpdateIconInfo;
var
  Stream: TMemoryStream;
  I: Integer;
begin
  EmptyIconInfo;
  Stream := TMemoryStream.Create;
  try
    FPropertyIcon.SaveToStream(Stream);
    Stream.Position := 0;
    Stream.Read(FIconDir, SizeOf(TCursorOrIcon));
    SetLength(FIconDirectoryEntry, FIconDir.Count);
    for I := 0 to FIconDir.Count - 1 do
    begin
      Stream.Read(FIconDirectoryEntry[I], SizeOf(TIconDirectoryEntry));
      Dec(FIconDirectoryEntry[I].bWidth, Byte(FIconDirectoryEntry[I].bWidth = 0));
      Dec(FIconDirectoryEntry[I].bHeight, Byte(FIconDirectoryEntry[I].bHeight = 0));
      if FIconDirectoryEntry[I].wBitCount = 32 then
        if FAlphaBitmap = nil then FAlphaBitmap := TBitmap.Create;
    end;
  finally
    Stream.Free;
  end;
end;

//  Своевременная реакция на все изменения, произошедшие с иконкой...
// =============================================================================
procedure TFWCustomIconEx.OnIconChange(Sender: TObject);
begin
  if FPropertyIcon.Empty then
  begin
    EmptyIconInfo;
    Invalidate;
  end
  else
  begin
    UpdateIconInfo;
    ShowBestFormat;
  end;
end;

//  Отрисовка
// =============================================================================
procedure TFWCustomIconEx.Paint;
var
  ACurrentBitmapInfo: PBitmapInfoHeader;
begin
  inherited;
  Canvas.Lock;
  try
  
    if csDesigning in ComponentState then
    begin
      Canvas.Pen.Style := psDash;
      Canvas.Pen.Color := clBlack;
      Canvas.Brush.Style := bsClear;
      Canvas.Rectangle(GetClientRect);
    end;

    if FormatCount > 0 then
      if CurrentFormat >= 0 then
	    begin
        ACurrentBitmapInfo := GetBitmapInfo(FCurrentFormat); // BUG FIX
        GetDIBBitmapEx(ACurrentBitmapInfo^, Canvas, Point(0, 0));
      end;
  finally
    Canvas.Unlock;
  end;
end;

//  Сохранение иконки в файл
// =============================================================================
procedure TFWCustomIconEx.SaveToFile(const FileName: String;
  Formats: TFWIconExFormatSet);
var
  F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(F, Formats);
    FlushFileBuffers(F.Handle);
  finally
    F.Free;
  end;
end;

//  Сохранение иконки в стрим
// =============================================================================
procedure TFWCustomIconEx.SaveToStream(Stream: TStream;
  Formats: TFWIconExFormatSet);
var
  IconDir: TCursorOrIcon;
  IconDirectoryEntryes: array of TIconDirectoryEntry;
  NeedFormatCount, I: Integer;
  IcoStream: TMemoryStream;
begin
  Stream.Size := 0;

  // Определяем, сколько форматов будет присутствовать в иконке
  NeedFormatCount := 0;
  SetLength(IconDirectoryEntryes, FormatCount);
  for I := 0 to FormatCount - 1 do
    if I in Formats then
    begin
      IconDirectoryEntryes[NeedFormatCount] := FIconDirectoryEntry[I];
      Inc(NeedFormatCount);
    end;
  SetLength(IconDirectoryEntryes, NeedFormatCount);

  // Подготавливаем заголовок иконки
  with IconDir do
  begin
    Reserved := 0;
    wType := RC3_ICON;
    Count := NeedFormatCount;
  end;

  // Сохраняем в стрим заголовок
  Stream.Write(IconDir, SizeOf(TCursorOrIcon));

  // Форматы иконок
  for I := 0 to NeedFormatCount - 1 do
  begin
    // Правим смещения каждого формата
    if I = 0 then
      IconDirectoryEntryes[I].dwImageOffset :=
        SizeOf(TCursorOrIcon) + NeedFormatCount * SizeOf(TIconDirectoryEntry)
      else
        IconDirectoryEntryes[I].dwImageOffset :=
          IconDirectoryEntryes[I - 1].dwImageOffset +
          IconDirectoryEntryes[I - 1].dwBytesInRes;
    // Сохраняем в стрим
    Stream.Write(IconDirectoryEntryes[I], SizeOf(TIconDirectoryEntry));
  end;

  // Данные по иконкам
  IcoStream := TMemoryStream.Create;
  try
    FPropertyIcon.SaveToStream(IcoStream);
    for I := 0 to FormatCount - 1 do
      if I in Formats then
      begin
        IcoStream.Position := FIconDirectoryEntry[I].dwImageOffset;
        Stream.CopyFrom(IcoStream, FIconDirectoryEntry[I].dwBytesInRes);
    end;
  finally
    IcoStream.Free;
  end;
end;

//  Если выставлен AutoSize то запрещаем менять размеры иконки
// =============================================================================
procedure TFWCustomIconEx.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  if AutoSize then
    if FormatCount > 0 then
      if CurrentFormat >= 0 then
      begin
        AWidth := FIconDirectoryEntry[CurrentFormat].bWidth;
        AHeight := FIconDirectoryEntry[CurrentFormat].bWidth;
      end;
    inherited;
end;

//  Выставляем требуемый для отображения формат иконки
// =============================================================================
procedure TFWCustomIconEx.SetCurrentFormat(const Value: Integer);
begin
  if (Value < -1) or (Value >= FormatCount) then
    raise EListError.CreateResFmt(@SListIndexError, [Value]);
  FCurrentFormat := Value;
  FCurrentBitmapInfo := GetBitmapInfo(FCurrentFormat);
  SetBounds(Left, Top,Width, Height);
  Invalidate;
end;

//  Загрузка новой иконки в компонент
// =============================================================================
procedure TFWCustomIconEx.SetIcon(const Value: TIcon);
begin
  FPropertyIcon.Assign(Value);
end;

// =============================================================================
//  Модификация от n0wheremany
// =============================================================================

procedure TFWCustomIconEx.CMMouseEnter(var AMsg: TMessage);
begin
  inherited;
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TFWCustomIconEx.CMMouseLeave(var AMsg: TMessage);
begin
  inherited;
  if Assigned(FOnMouseLeave) then
    FOnMouseLeave(Self);
end;

end.
