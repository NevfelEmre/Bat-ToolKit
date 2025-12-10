@echo off
REM Betigin calistigi klasoru aktif dizin yapar
cd /d "%~dp0"

REM Turkce karakter ayari
chcp 65001 >nul

REM Tum ciktiyi (parantez icini) dogrudan txt dosyasina yonlendiriyoruz
(
    echo ============================================================
    echo  WAV DOSYA LISTESI
    echo ============================================================
    echo.

    REM Alt klasorleri gez (r), sadece isim ve uzanti yaz (nxa)
    for /r %%a in (*.wav) do (
        echo %%~nxa
    )
    echo.
    echo ============================================================
    echo  LISTE SONU
    echo ============================================================
) > WavFileNames.txt

REM Pencereyi bekleme yapmadan kapat
exit