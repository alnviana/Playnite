param(
    [Parameter(Mandatory=$true)]
    [string]$OldCommit,
    [Parameter(Mandatory=$true)]
    [string]$NewCommit,    
    [Parameter(Mandatory=$true)]
    [string]$OldVersion,    
    [Parameter(Mandatory=$true)]
    [string]$NewVersion   
)

$global:ErrorActionPreference = "Stop"
& .\common.ps1

$global:gitOutPath = "gitout.txt"
$changeBaseLogDir = "..\source\Tools\Playnite.Toolbox\Templates\Themes\Changelog"
$changeLogDir = Join-Path $changeBaseLogDir "$OldVersion-$NewVersion"
New-EmptyFolder $changeLogDir

function SaveXamlile()
{
    param(
        $commitHash,
        $filePath,
        $targetPath
    )

    New-FolderFromFilePath $targetPath
    Start-Process "git" "--no-pager show $($commitHash):$($filePath)" -NoNewWindow -Wait -RedirectStandardOutput $targetPath
}

function SaveDiffFile()
{
    param(
        $commitHash,
        $filePath,
        $targetPath
    )

    New-FolderFromFilePath $targetPath
    Start-Process "git" "--no-pager show $($commitHash):$($filePath)" -NoNewWindow -Wait -RedirectStandardOutput $targetPath
    (Get-FileHash $targetPath -Algorithm MD5).Hash | Out-File $targetPath
}

function GetFileList
{
    param (
        $commitHash,
        $rootPath
    )

    Start-Process "git" "--no-pager ls-tree -r --name-only --full-name $commitHash $rootPath" -NoNewWindow -Wait -RedirectStandardOutput $gitOutPath
    return Get-Content $gitOutPath
}

function ExportThemeFiles
{
    param (
        $commitHash,
        $themeRootPath,
        $destination
    )

    $files = GetFileList $commitHash $themeRootPath
    foreach ($file in $files)
    {
        $subPath = $file -replace ".+(DesktopApp|FullscreenApp)/Themes/", ""
        $subPath = $subPath.Replace("/Default/", "/")

        if ($file -match "theme\.yaml$")
        {
            continue
        }

        if ($subPath -match "\.xaml$")
        {
            SaveXamlile $OldCommit $file (Join-Path $destination $subPath)
        }
        else
        {            
            SaveDiffFile $OldCommit $file (Join-Path $destination $subPath)
        }
    }
}

try
{
    Start-Process "git" "--no-pager diff --name-status $OldCommit $NewCommit" -NoNewWindow -Wait -RedirectStandardOutput $gitOutPath
    $changes = Get-Content $gitOutPath | Where {$_ -match "(DesktopApp|FullscreenApp)/Themes/(Desktop|Fullscreen)/Default"}
    $changes | Out-File (Join-Path $changeBaseLogDir "$OldVersion-$NewVersion.txt")

    ExportThemeFiles $OldCommit "../source/Playnite.DesktopApp/Themes/Desktop/Default" $changeLogDir
    ExportThemeFiles $OldCommit "../source/Playnite.FullscreenApp/Themes/Fullscreen/Default"  $changeLogDir
    
    New-ZipFromDirectory $changeLogDir (Join-Path $changeBaseLogDir "$OldVersion.zip")
}
finally
{
    Remove-item $gitOutPath -Force -EA 0
    if (Test-Path $changeLogDir)
    {
        Remove-Item $changeLogDir -Recurse -EA 0
    }
}