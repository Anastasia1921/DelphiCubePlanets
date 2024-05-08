unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, OpenGL, Math, AppEvnts;

type

  // вектор из 3х компонент
  TVector3f = packed record
    case Byte of
      // к вектору можно обратиться по именам компонент
      0: (x, y, z: GLfloat);
      // которые могут оказаться цветами...
      1: (r, g, b: GLfloat);
      // или по индексу
      2: (v: array [0..2] of GLfloat);
  end;
// информация о планетах
  TPlanetInfo = record
    // нормаль орбиты
    nx, ny, nz: GLfloat;
    // радиус орбиты
    radius: GLfloat;
    // размер планеты
    s: GLfloat;
    // текущее положение относительно солнца
    suna: GLfloat;
    // изменение положения относительно солнца при обновлении
    dsuna: GLfloat;
  end;


  TMainForm = class(TForm)
    ApplicationEvents1: TApplicationEvents;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
  private
  FPrevTick : Cardinal ;
FAngle : GLfloat ;

    // углы поворота
  FTrackAX, FTrackAY: GLfloat;
  // предыдущие координаты мыши
  FMouseX, FMouseY: Integer;
  // нажата ли клавиша мыши
  FMouseDown: Boolean;
  // планеты
  FPlanets: array of TPlanetInfo;
 procedure InitializeScene;
 procedure Advance (Elapsed: Cardinal);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;
implementation

{$R *.dfm}

procedure TMainForm.InitializeScene;
begin
  // начальные углы трекбола
  FTrackAX:= -20.0;
  FTrackAY:= 20.0;
  // создадим и инициализируем планеты
  SetLength (FPlanets, 4);
  with FPlanets[0] do
  begin
    nx:= 0.0; ny:= 1.0; nz:= 0.0;
    radius:= 0.35;
    s:= 0.1;
    suna:= 0.0;
    dsuna:= 1.0;
  end;
  with FPlanets[1] do
  begin
    nx:= 0.2; ny:= 1.0; nz:= 0.2;
    radius:= 0.55;
    s:= 0.075;
    suna:= 0.0;
    dsuna:= -1.0;
  end;
  with FPlanets[2] do
  begin
    nx:= -0.5; ny:= 1.0; nz:= -0.5;
    radius:= 0.75;
    s:= 0.05;
    suna:= 0.0;
    dsuna:= 0.5;
  end;
  with FPlanets[3] do
  begin
    nx:= 0.5; ny:= 1.0; nz:= 0.5;
    radius:= 0.85;
    s:= 0.03;
    suna:= 0.0;
    dsuna:= 0.7;
  end;
end;

function Vector3f (x, y, z: GLfloat): TVector3f;
begin
  Result.x:= x;
  Result.y:= y;
  Result.z:= z;
end;

function Length3f (const v: TVector3f): GLfloat;
begin
  Result:= Sqrt (v.x * v.x + v.y * v.y + v.z * v.z);
end;

function Normalize3f (const v: TVector3f): TVector3f;
var
  L: GLfloat;
begin
  L:= Length3f (v);
  Result.x:= v.x / L;
  Result.y:= v.y / L;
  Result.z:= v.z / L;
end;

function Dot3f (const v1, v2: TVector3f): GLfloat;
begin
  Result:= v1.x * v2.x + v1.y * v2.y+ v1.z * v2.z;
end;

function Cross3f (const v1, v2: TVector3f): TVector3f;
begin
  Result.x:= v1.y * v2.z - v2.y * v1.z;
  Result.y:= v1.z * v2.x - v2.z * v1.x;
  Result.z:= v1.x * v2.y - v2.x * v1.y;
end;

procedure Orbit (nx, ny, nz: GLfloat; r: GLfloat; Draw: Boolean);
var
  i: Integer;
  n, nproj, j, rot: TVector3f;
  a, x, y: Glfloat;
begin
  // разворачиваем плоскость xOz в направлении вектора нормали орбиты
  n:= Normalize3f (Vector3f (nx, ny, nz));
  nproj:= Normalize3f (Vector3f (nx, ny, 0.0));
  j:= Vector3f (0.0, 1.0, 0.0);
  rot:= Cross3f (j, nproj);
  a:= Dot3f (j, nproj);
  glRotatef (ArcCos (a) * 180 / pi, rot.x, rot.y, rot.z);
  a:= Dot3f (n, nproj);
  if nz < 0 then
    glRotatef (ArcCos (a) * 180 / pi, -1.0, 0.0, 0.0)
  else
    glRotatef (ArcCos (a) * 180 / pi, 1.0, 0.0, 0.0);
  // построим окружность
  if Draw then
  begin
    glBegin (GL_LINE_LOOP);
      for i:= 0 to 359 do
      begin
        x:= r * cos (i * pi / 180);
        y:= r * sin (i * pi / 180);
        glVertex3f (x, 0.0, y);
      end;
    glEnd;
  end;
end;

function TrackSmooth (Delta: Integer): GLfloat;
begin
  if Delta < 3 then
    Result:= Delta / 2
  else if Delta < 7 then
    Result:= 3 + (Delta - 3) / 3
  else
    Result:= 7 + (Delta - 7) / 5;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  DC: HDC;
  RC: HGLRC;
  iPixelFormat: Integer;
  pfd: TPixelFormatDescriptor;
begin
  DC:= 0;
  RC:= 0;
  ZeroMemory (@pfd, SizeOf (pfd));
  pfd.nSize:= SizeOf (pfd);
  pfd.nVersion:= 1;
  pfd.dwFlags:=     PFD_DOUBLEBUFFER or PFD_DRAW_TO_WINDOW or
    PFD_SUPPORT_OPENGL or
    PFD_GENERIC_ACCELERATED;
pfd.iPixelType:= PFD_TYPE_RGBA; pfd.cColorBits:= 24;            
  pfd.cAlphaBits:= 8;             
  pfd.cDepthBits:= 24;            
  pfd.cStencilBits:= 8;           
  pfd.cAccumBits:= 24;            
  DC:= GetDC (Handle);	//1
iPixelFormat:= ChoosePixelFormat (DC, @pfd);		//2
   SetPixelFormat (DC, iPixelFormat, @pfd);	//3
   RC:= wglCreateContext (DC);//4
   wglMakeCurrent (DC, RC);//5

  // запускаем OpenGL

  // отключим стандартный фон на форме
  Brush.Style:= bsClear;

  // создадим сцену
  InitializeScene;
  // устанавливаем цвет очистки буфера кадра - темно-синий
  glClearColor (0.0, 0.0, 0.25, 1.0);
  // устанавливаем порядок обхода вершин
  glFrontFace (GL_CW);
  // и включаем отсечение нелицевых граней
  glCullFace (GL_BACK);
  glEnable (GL_CULL_FACE);
  // разрешаем тест глубины
  glEnable (GL_DEPTH_TEST);


end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  DC : HDC;
  RC : HGLRC;
begin
 RC := wglGetCurrentContext();
 DC := wglGetCurrentDC();
 wglMakeCurrent (0, 0);
 wglDeleteContext (RC);
 ReleaseDC (Handle, DC);
end;

procedure MyCube;
begin
   glBegin(GL_QUADS);
    glColor3f (1.0, 1.0, 1.0);
    glVertex2f (0.5, 0.5);	    //{1}
    glColor3f (0.0, 1.0, 0.0);
    glVertex2f (0.5, -0.5);	    //{2}
    glColor3f (0.0, 0.0, 1.0);
    glVertex2f (-0.5, -0.5);	  //{3}
    glColor3f (1.0, 0.0, 0.0);
    glVertex2f (-0.5, 0.5);	    //{4}
 glEnd;
end;
procedure Axes (cx, cy, cz: GLfloat; size: GLfloat);
begin
  size:= size / 2.0;
  glBegin (GL_LINES);
    // ось x
    glColor3f (0.0, 0.0, 1.0);
    glVertex3f (cx - size, 0.0, 0.0);
    glColor3f (1.0, 0.0, 0.0);
    glVertex3f (cx + size, 0.0, 0.0);
    // ось y
    glColor3f (0.0, 0.0, 1.0);
    glVertex3f (0.0, cy - size, 0.0);
    glColor3f (1.0, 0.0, 0.0);
    glVertex3f (0.0, cy + size, 0.0);
    // ось z
    glColor3f (0.0, 0.0, 1.0);
    glVertex3f (0.0, 0.0, cz - size);
    glColor3f (1.0, 0.0, 0.0);
    glVertex3f (0.0, 0.0, cz + size);
  glEnd;
end;
procedure ColorRgb (Color: TColor; var r, g, b: Byte);
var
  rgb: Longint;
begin
  rgb:= ColorToRGB (Color);
  r:= GetRValue (rgb);
  g:= GetGValue (rgb);
  b:= GetBValue (rgb);
end;

procedure Cube (cx, cy, cz: GLfloat; size: GLfloat; cFrom, cTo: TColor);
var
  rf, gf, bf: Byte;
  rt, gt, bt: Byte;
  rm, gm, bm: Byte;
begin
  // получаем компоненты R, G, B переданных цветов
  ColorRgb (cFrom, rf, gf, bf);
  ColorRgb (cTo, rt, gt, bt);
  // и вычислим промежуточный цвет
  rm:= rf + (rt - rf) div 2;
  gm:= gf + (gt - gf) div 2;
  bm:= bf + (bt - bf) div 2;
  // рисуем грани куба
  size:= size / 2.0;
  glBegin (GL_QUADS);
    // нижняя грань
    glColor3ub (rf, gf, bf);
    glVertex3f (cx + size, cy - size, cz - size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy - size, cz + size);
    glColor3ub (rt, gt, bt);
    glVertex3f (cx - size, cy - size, cz + size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy - size, cz - size);
    // задняя грань
    glColor3ub (rf, gf, bf);
    glVertex3f (cx - size, cy - size, cz - size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy + size, cz - size);
    glColor3ub (rt, gt, bt);
    glVertex3f (cx + size, cy + size, cz - size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy - size, cz - size);
    // левая грань
    glColor3ub (rt, gt, bt);
    glVertex3f (cx - size, cy - size, cz + size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy + size, cz + size);
    glColor3ub (rf, gf, bf);
    glVertex3f (cx - size, cy + size, cz - size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy - size, cz - size);
    // передняя грань
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy - size, cz + size);
    glColor3ub (rf, gf, bf);
    glVertex3f (cx + size, cy + size, cz + size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy + size, cz + size);
    glColor3ub (rt, gt, bt);
    glVertex3f (cx - size, cy - size, cz + size);
    // правая грань
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy - size, cz - size);
    glColor3ub (rt, gt, bt);
    glVertex3f (cx + size, cy + size, cz - size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy + size, cz + size);
    glColor3ub (rf, gf, bf);
    glVertex3f (cx + size, cy - size, cz + size);
    // верхняя грань
    glColor3ub (rm, gm, bm);
    glVertex3f (cx - size, cy + size, cz - size);
    glColor3ub (rf, gf, bf);
    glVertex3f (cx - size, cy + size, cz + size);
    glColor3ub (rm, gm, bm);
    glVertex3f (cx + size, cy + size, cz + size);
    glColor3ub (rt, gt, bt);
    glVertex3f (cx + size, cy + size, cz - size);   
  glEnd;
end;


procedure TMainForm.FormPaint(Sender: TObject);

var
  i: Integer;
begin
  // очищаем буфер кадра, устанавливая цвет его пикселей
  // равным цвету очистки, и буфер глубины
  glClear (GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  // задаем видовое преобразование
  glLoadIdentity;
  // преобразование трекбола
  glRotatef (FTrackAX, 1.0, 0.0, 0.0);
  glRotatef (FTrackAY, 0.0, 1.0, 0.0);
  // рисуем оси координат
  Axes (0.0, 0.0, 0.0, 1.7);
  // рисуем солнце
  Cube (0.0, 0.0, 0.0, 0.2, clYellow, clRed);
  // рисуем планеты
  for i:= Low (FPlanets) to High (FPlanets) do
  with FPlanets[i] do
  begin
    glPushMatrix;
    // поворачиваем планету относительно солнца
    glRotatef (suna, nx, ny, nz);
    // орбита, она же поворачивает плоскость
    glColor3f (0.4, 0.4, 0.4);
    Orbit (nx, ny, nz, radius, True);
    // и куб для планеты
    Cube (radius, 0.0, 0.0, s, clYellow, clGreen);
    glPopMatrix;
  end;
  // после завершения рисования необходимо выполнить обмен буферов
  // для показа изображения пользователю
  SwapBuffers (wglGetCurrentDC);
end;


procedure TMainForm.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // запоминаем параметры нажатия мыши
  FMouseDown:= True;
  FMouseX:= X;
  FMouseY:= Y;
  // захватываем ввод от мыши, теперь наше окно всегда получает
  // события от мыши, где бы ни находился курсор
  SetCapture (Handle);

end;

procedure TMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
 if FMouseDown then
  begin
    // вычислим углы поворота для видового преобразования
    // исходя из изменения положения мыши
    FTrackAY:= FTrackAY - TrackSmooth (X - FMouseX);
    FTrackAX:= FTrackAX - TrackSmooth (Y - FMouseY);
    if FTrackAX < -90.0 then
      FTrackAX:= -90.0;
    if FTrackAX > 90.0 then
      FTrackAX:= 90.0;
    // запомним новую позицию мыши
    FMouseX:= X;
    FMouseY:= Y;
  end;

end;

procedure TMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // освобождаем мышь
  ReleaseCapture;
  FMouseDown:= False;


end;

procedure TMainForm.Advance (Elapsed: Cardinal);
var
  i: Integer;
begin
  // обновляем углы поворота планет
  for i:= Low (FPlanets) to High (FPlanets) do
  with FPlanets[i] do
  begin
    suna:= suna + dsuna;
    if suna > 360.0 then
      suna:= suna - 360.0;
  end;
end;

procedure TMainForm.ApplicationEvents1Idle(Sender: TObject;
  var Done: Boolean);

var
  Tick: Cardinal;
begin
  // вычисляем сколько времени прошло с последнего обновления
  Tick:= GetTickCount;
  // если прошло более 20ms обновляем анимацию
  if Tick - FPrevTick > 20 then
  begin
    Advance (Tick - FPrevTick);
    Invalidate;
    FPrevTick:= Tick;
    // передаем управление другим потокам
    Sleep (0);
  end;
  Done:= False;

end;

end.
