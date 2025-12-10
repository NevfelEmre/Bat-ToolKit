@echo off
setlocal enabledelayedexpansion

:: --- 1. AYARLAR ---
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: FFmpeg ve Probe yollari
set "FFMPEG=Library\ffmpeg.exe"
set "FFPROBE=Library\ffprobe.exe"

:: Klasor kontrolu
if not exist "%FFMPEG%" (
    echo [HATA] Library klasorunde ffmpeg.exe BULUNAMADI!
    pause
    exit /b
)

:: --- 2. DOSYA GIRISI ---
echo.
echo ========================================================
echo     SES/VIDEO HIZ DEGISTIRICI (V7 - HIGH QUALITY)
echo ========================================================
echo.
echo [BILGI] Bu surum 'Rubberband' teknolojisi ile
echo sesin dogalligini bozmadan hizlandirma yapar.
echo.
echo Lutfen islenecek dosyayi surukleyip birakin:
set /p "userPath=Dosya Yolu: "

set "userPath=%userPath:"=%"

if not exist "%userPath%" (
    echo [HATA] Dosya bulunamadi.
    pause
    exit /b
)

for %%F in ("%userPath%") do (
    set "inputFile=%%~fF"
    set "fileName=%%~nF"
    set "fileExt=%%~xF"
)

:: --- 3. ANALIZ ---
echo.
echo Analiz yapiliyor...

:: Video kontrolu
"%FFPROBE%" -v error -select_streams v:0 -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "%inputFile%" > info_type.txt 2>nul
set /p streamType=<info_type.txt
if exist info_type.txt del info_type.txt

set "hasVideo=0"
if "%streamType%"=="video" set "hasVideo=1"

:: Sure ve Sample Rate
"%FFPROBE%" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "%inputFile%" > info_dur.txt 2>nul
set /p currentDuration=<info_dur.txt
if exist info_dur.txt del info_dur.txt

"%FFPROBE%" -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "%inputFile%" > info_rate.txt 2>nul
set /p sampleRate=<info_rate.txt
if exist info_rate.txt del info_rate.txt

if "!currentDuration!"=="" (
    echo [HATA] Dosya okunamadi.
    pause
    exit /b
)

echo.
echo Dosya: %fileName%%fileExt%
echo Sure: %currentDuration% sn - Rate: %sampleRate% Hz
echo.

:: --- 4. AYARLAR ---
:ask_pitch
set /p "keepPitch=Pitch (Ses tonu) sabitlensin mi? [y/n] (y=Dogal Kalite / n=Incelsin/Kalinslassin): "
if /i "%keepPitch%" neq "y" if /i "%keepPitch%" neq "n" goto ask_pitch

:ask_mode
echo.
echo [1] Hedef Sure Belirle (Saniye)
echo [2] Hiz Yuzdesi Belirle (Orn: 200 = 2x Hiz)
set /p "mode=Seciminiz (1 veya 2): "

:: --- 5. HESAPLAMA ---
set "speedFactor=1.0"

if "%mode%"=="1" (
    set /p "targetDuration=Hedef Sure (saniye): "
    powershell -command "$c = [double]%currentDuration%; $t = [double]!targetDuration!; $res = $c / $t; [Math]::Round($res, 6)" > info_math.txt
) else if "%mode%"=="2" (
    set /p "targetPercent=Hiz Yuzdesi: "
    powershell -command "$p = [double]!targetPercent!; $res = $p / 100; [Math]::Round($res, 6)" > info_math.txt
) else (
    goto ask_mode
)

set /p speedFactor=<info_math.txt
if exist info_math.txt del info_math.txt
set "speedFactor=!speedFactor:,=.!"

echo.
echo Islem Basliyor... (Hiz: %speedFactor%x)

:: --- 6. FILTRE AYARLARI (YUKSEK KALITE) ---

:: Video Hizlandirma
if "%hasVideo%"=="1" (
    powershell -command "$s = [double](('%speedFactor%').Replace('.',',')); $v = 1/$s; [Math]::Round($v, 6)" > info_pts.txt
    set /p videoPts=<info_pts.txt
    set "videoPts=!videoPts:,=.!"
    if exist info_pts.txt del info_pts.txt
)

:: Ses Filtresi (BURASI DEGISTI)
if /i "%keepPitch%"=="y" (
    :: Rubberband Kullanimi (Daha dogal ses)
    :: tempo parametresi hizi degistirir, pitch sabit kalir
    set "audioFilter=rubberband=tempo=%speedFactor%"
) else (
    :: Klasik Sample Rate Degisimi (Chipmunk etkisi icin en temizi budur)
    powershell -command "$s = [double](('%speedFactor%').Replace('.',',')); $sr = [int]%sampleRate%; $res = [int]($sr * $s); $res" > info_rate2.txt
    set /p newRate=<info_rate2.txt
    if exist info_rate2.txt del info_rate2.txt
    set "audioFilter=asetrate=!newRate!,aresample=%sampleRate%"
)

set "tempOut=_temp_%fileName%%fileExt%"
set "finalOut=%fileName%%fileExt%"

:: --- 7. CALISTIR ---
echo Lutfen bekleyin, Rubberband islemi biraz zaman alabilir...
echo.

if "%hasVideo%"=="1" (
    "%FFMPEG%" -y -v error -stats -i "%inputFile%" -filter_complex "[0:v]setpts=%videoPts%*PTS[v];[0:a]%audioFilter%[a]" -map "[v]" -map "[a]" "%tempOut%"
) else (
    "%FFMPEG%" -y -v error -stats -i "%inputFile%" -filter:a "%audioFilter%" "%tempOut%"
)

if exist "%tempOut%" (
    move /y "%tempOut%" "%finalOut%" >nul
    echo.
    echo BASARILI! Dosya kaydedildi:
    echo %SCRIPT_DIR%%finalOut%
) else (
    echo.
    echo [HATA] Islem basarisiz oldu.
    echo Eger 'No such filter: rubberband' hatasi alirsaniz,
    echo ffmpeg surumunuz bu kutuphaneyi desteklemiyordur.
)

echo.
pause