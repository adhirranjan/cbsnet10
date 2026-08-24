@echo off
REM Push the docs folder ONLY to https://github.com/adhirranjan/cbsnet10
REM The git repo is rooted here in docs\ -- nothing outside this folder is ever staged.
REM migration-estimate\node_modules is excluded via docs\.gitignore.
REM Usage: push-to-github.bat ["commit message"]
setlocal
REM %~dp0 = this .bat file's own folder, i.e. E:\Adhir\AdWork\TrustBank.Code\TflCbsNet10Sol\docs\
cd /d "%~dp0"

set "MSG=%~1"
if "%MSG%"=="" set "MSG=Update docs"

if not exist ".git" (git init -b main || goto :fail)

git remote get-url origin >nul 2>&1 && (
  git remote set-url origin https://github.com/adhirranjan/cbsnet10.git
) || (
  git remote add origin https://github.com/adhirranjan/cbsnet10.git
)

git add -A || goto :fail

git diff --cached --quiet && (
  echo Nothing to commit.
) || (
  git commit -m "%MSG%" || goto :fail
)

REM --force-with-lease: this docs folder is the source of truth; it overwrites the
REM old "Add files via upload" history on GitHub, but still aborts if someone else
REM pushed a commit we have not fetched.
git push -u --force-with-lease origin HEAD || goto :fail
echo Done.
exit /b 0

:fail
echo FAILED ^(exit %errorlevel%^)
exit /b %errorlevel%
