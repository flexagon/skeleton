@echo off
setlocal enabledelayedexpansion

set PHPUNIT=..\vendor\bin\phpunit
set CONFIG=..\phpunit.xml

set TARGET=%1
set FILTER=%2

set ENV_COUNT=0
set OPT_COUNT=0

set ENV_ARGS=
set OPT_ARGS=

rem 3~7번 인자 처리
for %%A in (%3 %4 %5 %6 %7) do (
    if not "%%A"=="" (

        rem KEY=VALUE 체크
        echo %%A | find "=" >nul
        if not errorlevel 1 (
            set "ARG=%%A"
            call :add_env
        ) else (
            rem KEY:VALUE 체크
            echo %%A | find ":" >nul
            if not errorlevel 1 (
                call :convert_colon %%A
                call :add_env
            ) else (
                rem --option 체크
                echo %%A | find "--" >nul
                if not errorlevel 1 (
                    set /a OPT_COUNT+=1
                    if !OPT_COUNT! LEQ 5 (
                        set "OPT_ARGS=!OPT_ARGS! %%A"
                    ) else (
                        echo Too many PHPUnit options. Max 5 allowed.
                        exit /b 1
                    )
                ) else (
                    echo Invalid argument: %%A
                    echo Use KEY=VALUE, KEY:VALUE or --phpunit-option
                    exit /b 1
                )
            )
        )
    )
)

rem ENV 적용
for %%E in (!ENV_ARGS!) do (
    for /f "tokens=1,* delims==" %%K in ("%%E") do (
        set "%%K=%%L"
    )
)

rem 실행
if not "%FILTER%"=="" (
    php "%PHPUNIT%" --configuration "%CONFIG%" --filter "%FILTER%" "%TARGET%" %OPT_ARGS%
) else (
    php "%PHPUNIT%" --configuration "%CONFIG%" "%TARGET%" %OPT_ARGS%
)

endlocal
goto :eof


:add_env
set /a ENV_COUNT+=1
if %ENV_COUNT% LEQ 5 (
    set "ENV_ARGS=!ENV_ARGS! !ARG!"
) else (
    echo Too many ENV arguments. Max 5 allowed.
    exit /b 1
)
goto :eof


:convert_colon
set "TMP=%~1"
for /f "tokens=1,* delims=:" %%K in ("%TMP%") do (
    set "ARG=%%K=%%L"
)
goto :eof