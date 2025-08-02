# ΢�� TinyPin ��ƽ̨��װ�������ű� (PowerShell)
# ֧�� x64��Win32��ARM64 ƽ̨���Զ�������

param(
    [string]$Configuration = "Release",
    [switch]$SkipBuild = $false,
    [switch]$Verbose = $false
)

# ���ÿ���̨����Ϊ GBK
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("GBK")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "΢�� TinyPin ��ƽ̨��װ�������ű�" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ����·�����ļ�
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$SolutionFile = Join-Path $ProjectRoot "TinyPin.sln"
$InstallerScript = "TinyPin.iss"
$InstallerDir = Join-Path $ProjectRoot "tools\Scripts"

# ����֧�ֵ�ƽ̨
$Platforms = @("x64", "Win32", "ARM64")

# �������ͳ��
$BuildResults = @()

function Write-Step {
    param([string]$Message, [string]$Color = "Yellow")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "[��] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[��] $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# ����Ҫ����
Write-Step "��鹹������..."

$MSBuildPath = Get-Command "msbuild.exe" -ErrorAction SilentlyContinue
if (-not $MSBuildPath) {
    Write-Error "�Ҳ��� MSBuild����ȷ���Ѱ�װ Visual Studio �� Build Tools"
    exit 1
}

$ISCCPath = Join-Path $ProjectRoot "tools\InnoSetup6\ISCC.exe"
if (-not (Test-Path $ISCCPath)) {
    Write-Error "�Ҳ��� Inno Setup ������: $ISCCPath"
    Write-Error "��ȷ�� Inno Setup �������ѷ�������Ŀ�� tools\InnoSetup6\ Ŀ¼��"
    exit 1
}

Write-Success "�����������ͨ��"
Write-Host ""

# ��ʼ������ƽ̨
$TotalPlatforms = $Platforms.Count
$CurrentPlatform = 0

foreach ($Platform in $Platforms) {
    $CurrentPlatform++
    Write-Step "[$CurrentPlatform/$TotalPlatforms] ���� $Platform ƽ̨..." "Cyan"
    
    $BuildSuccess = $true
    $ErrorMessage = ""
    
    try {
        # ������Ŀ
        if (-not $SkipBuild) {
            Write-Host "  ���� $Platform �汾..."
            Set-Location $ProjectRoot
            
            $OutDir = Join-Path $ProjectRoot "build\compile\$Configuration\$Platform\"
            $BuildArgs = @(
                $SolutionFile,
                "/p:Configuration=$Configuration",
                "/p:Platform=$Platform",
                "/p:OutDir=$OutDir"
            )
            
            if (-not $Verbose) {
                $BuildArgs += "/verbosity:minimal"
            }
            
            $BuildResult = & msbuild @BuildArgs
            if ($LASTEXITCODE -ne 0) {
                throw "����ʧ�ܣ��˳�����: $LASTEXITCODE"
            }
            
            Write-Success "�������"
        }
        
        # ����ִ���ļ��Ƿ����
        $ExePath = Join-Path $ProjectRoot "build\compile\$Configuration\$Platform\TinyPin.exe"
        if (-not (Test-Path $ExePath)) {
            throw "�Ҳ����������: $ExePath"
        }
        
        # �����װ����
        Write-Host "  ��� $Platform ��װ��..."
        Set-Location $InstallerDir
        
        $SourcePath = Join-Path $ProjectRoot "build\compile\$Configuration\$Platform\TinyPin.exe"
        $OutputPath = Join-Path $ProjectRoot "build\installer"
        $PackageResult = & $ISCCPath $InstallerScript "/Dp=$Platform" "/Ds=$SourcePath" "/Do=$OutputPath"
        if ($LASTEXITCODE -ne 0) {
            throw "���ʧ�ܣ��˳�����: $LASTEXITCODE"
        }
        
        # ������ɵİ�װ��
        $SetupFile = Join-Path $OutputPath "TinyPin-1.0-$Platform-setup.exe"
        if (Test-Path $SetupFile) {
            $FileSize = [math]::Round((Get-Item $SetupFile).Length / 1MB, 2)
            $SetupFileName = Split-Path $SetupFile -Leaf
            Write-Host "  [��] $Platform ��װ�����ɳɹ�: $SetupFileName ($FileSize MB)" -ForegroundColor Green
            $BuildSuccess = $true
        } else {
            throw "�Ҳ������ɵİ�װ��: $SetupFile"
        }
        
        Write-Success "$Platform ƽ̨�������"
    }
    catch {
        $BuildSuccess = $false
        $ErrorMessage = $_.Exception.Message
        Write-Error "$Platform ƽ̨����ʧ��: $ErrorMessage"
    }
    
    # ��¼�������
    $BuildResults += @{
        Platform = $Platform
        Success = $BuildSuccess
        Error = $ErrorMessage
    }
    
    Write-Host ""
}

# ��ʾ����ժҪ
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "����ժҪ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$SuccessCount = 0
$FailureCount = 0

foreach ($Result in $BuildResults) {
    if ($Result.Success) {
        Write-Success "$($Result.Platform) ƽ̨�����ɹ�"
        $SuccessCount++
    }
    else {
        Write-Error "$($Result.Platform) ƽ̨����ʧ��: $($Result.Error)"
        $FailureCount++
    }
}

Write-Host ""
Write-Host "�ɹ�: $SuccessCount ��ƽ̨" -ForegroundColor Green
Write-Host "ʧ��: $FailureCount ��ƽ̨" -ForegroundColor Red

# ��ʾ���ɵİ�װ��
if ($SuccessCount -gt 0) {
    Write-Host ""
    Write-Host "���ɵİ�װ��:" -ForegroundColor Yellow
    $InstallerOutputDir = Join-Path $ProjectRoot "build\installer"
    $SetupFiles = Get-ChildItem -Path $InstallerOutputDir -Name "TinyPin-1.0-*-setup.exe" -ErrorAction SilentlyContinue
    if ($SetupFiles) {
        foreach ($File in $SetupFiles) {
            $FilePath = Join-Path $InstallerOutputDir $File
            $FileInfo = Get-Item $FilePath
            $SizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
            Write-Host "  $File ($SizeMB MB)" -ForegroundColor White
        }
    }
    else {
        Write-Host "  δ�ҵ���װ���ļ�" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "�����ļ�������: $(Join-Path $ProjectRoot 'build\compile')" -ForegroundColor Green
Write-Host "��װ��������: $(Join-Path $ProjectRoot 'build\installer')" -ForegroundColor Green
Write-Host "�������ʱ��: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# �����˳�����
if ($FailureCount -gt 0) {
    exit 1
}
else {
    exit 0
}