# YouTube agent skill 전역 설치 스크립트 (Windows PowerShell 5.1 / PowerShell 7)
# 원본: https://github.com/Jakeschincariol/youtube-agent-skill  (검토한 커밋 a2feb21 에 고정)

$Repo        = 'https://github.com/Jakeschincariol/youtube-agent-skill'
$PinnedSha   = 'a2feb2104981a375ffd4f87ee04f4f5344ac43c6'
$ClaudeDir   = Join-Path $HOME '.claude'
$SkillsDir   = Join-Path $ClaudeDir 'skills'
$YoutubeDir  = Join-Path $ClaudeDir 'youtube'
$ClaudeMd    = Join-Path $ClaudeDir 'CLAUDE.md'
$Stamp       = Get-Date -Format 'yyyyMMdd-HHmmss'
$WorkDir     = Join-Path ([IO.Path]::GetTempPath()) "youtube-agent-skill-$Stamp"
$Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)

function Step($msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "[중단] $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. clone + 스킬 복사
Step '1/4 저장소 받기 (커밋 a2feb21 고정)'
if (Get-Command git -ErrorAction SilentlyContinue) {
    git clone -q $Repo $WorkDir
    if ($LASTEXITCODE -ne 0) { Fail 'git clone 실패' }
    git -C $WorkDir checkout -q $PinnedSha
    if ($LASTEXITCODE -ne 0) { Fail "커밋 $PinnedSha 를 찾을 수 없음" }
    $head = (git -C $WorkDir rev-parse HEAD).Trim()
    $latest = (git -C $WorkDir rev-parse origin/HEAD).Trim()
    Write-Host "  설치할 커밋 : $head"
    if ($latest -ne $PinnedSha) {
        Write-Host "  [주의] 저장소 최신 커밋($latest)이 검토한 버전과 다릅니다. 검토한 a2feb21 로 설치합니다." -ForegroundColor Yellow
    }
} else {
    Write-Host '  git 없음 -> 커밋 a2feb21 zip 다운로드'
    $zip = "$WorkDir.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing "$Repo/archive/$PinnedSha.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $WorkDir
    $WorkDir = (Get-ChildItem $WorkDir -Directory | Select-Object -First 1).FullName
}

$srcSkills = Get-ChildItem (Join-Path $WorkDir 'skills') -Directory -Filter 'yt-*'
if ($srcSkills.Count -ne 11) { Fail "skills/yt-* 폴더가 11개가 아님 ($($srcSkills.Count)개)" }

New-Item -ItemType Directory -Force $SkillsDir | Out-Null
foreach ($s in $srcSkills) {
    $dest = Join-Path $SkillsDir $s.Name
    if (Test-Path $dest) {
        # 백업은 skills 폴더 밖에 둔다 (안에 두면 같은 스킬이 두 번 등록됨)
        $bakDir = Join-Path (Join-Path $ClaudeDir 'yt-skills-backup') $Stamp
        New-Item -ItemType Directory -Force $bakDir | Out-Null
        Move-Item $dest (Join-Path $bakDir $s.Name)
        Write-Host "  기존 $($s.Name) -> yt-skills-backup/$Stamp 로 백업"
    }
    Copy-Item $s.FullName $dest -Recurse
}
Write-Host "  복사 완료 -> $SkillsDir"

# ---------------------------------------------------------------- 2. voice.md
Step '2/4 voice.md 템플릿 복사 (내용은 비워둔 템플릿 그대로)'
New-Item -ItemType Directory -Force $YoutubeDir | Out-Null
$voiceDest = Join-Path $YoutubeDir 'voice.md'
if (Test-Path $voiceDest) {
    Write-Host "  이미 있음 -> 덮어쓰지 않음: $voiceDest" -ForegroundColor Yellow
} else {
    Copy-Item (Join-Path (Join-Path $WorkDir 'templates') 'voice.md') $voiceDest
    Write-Host "  복사 완료 -> $voiceDest"
}

# ---------------------------------------------------------------- 3. Python + hookscore
Step '3/4 Python 3 확인 + hookscore.py 실행'
$py = $null
foreach ($cand in @(@('py','-3'), @('python'), @('python3'))) {
    if (-not (Get-Command $cand[0] -ErrorAction SilentlyContinue)) { continue }
    $pre = @(); if ($cand.Count -gt 1) { $pre = $cand[1..($cand.Count-1)] }
    $ver = & $cand[0] @pre --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $ver -match 'Python 3') { $py = $cand; Write-Host "  $($ver.Trim())  ($($cand -join ' '))"; break }
}
if (-not $py) {
    Write-Host '  Python 3 를 찾지 못했습니다. https://www.python.org/downloads/ 에서 설치 후 다시 실행하세요.' -ForegroundColor Red
    Write-Host '  (설치 화면에서 "Add python.exe to PATH" 체크) - 스킬 복사는 이미 끝났습니다.'
} else {
    $pre = @(); if ($py.Count -gt 1) { $pre = $py[1..($py.Count-1)] }
    $hookscore = Join-Path (Join-Path $SkillsDir 'yt-script') 'hookscore.py'
    $sample = 'You are wasting 20 minutes every night on dinner, and here is why.'
    & $py[0] @pre $hookscore --hook $sample
}

# ---------------------------------------------------------------- 4. CLAUDE.md 규칙
Step '4/4 ~/.claude/CLAUDE.md 에 /yt-script 후킹 규칙 추가'
$marker = '<!-- yt-script-hook-rule -->'
$rule = @"

$marker
## /yt-script 후킹 규칙
/yt-script 를 쓸 때는 항상 다음을 적용한다. (hookscore.py 는 영어 단어만 세서 한글 후킹은 점수가 9~25점에 몰리기 때문)
- 후킹은 한국어로 쓰고, 점수는 영어로 옮긴 문장으로 매긴다.
- 각 후킹 옆에 영어 문장과 점수를 같이 보여준다.
- 고른 두 개는 한국어로 다시 다듬는다.
- 스킬 원본 파일(~/.claude/skills/yt-*)은 고치지 않는다.

"@
$existing = ''
if (Test-Path $ClaudeMd) { $existing = [IO.File]::ReadAllText($ClaudeMd) }
if ($existing.Contains($marker)) {
    Write-Host '  이미 규칙이 있음 -> 건너뜀'
} else {
    if (Test-Path $ClaudeMd) { Copy-Item $ClaudeMd "$ClaudeMd.bak-$Stamp"; Write-Host "  기존 CLAUDE.md 백업 -> CLAUDE.md.bak-$Stamp" }
    [IO.File]::AppendAllText($ClaudeMd, $rule, $Utf8NoBom)
    Write-Host "  추가 완료 -> $ClaudeMd"
}

# ---------------------------------------------------------------- 결과 확인
Step '설치 결과'
$installed = Get-ChildItem $SkillsDir -Directory -Filter 'yt-*'
$i = 0
foreach ($d in $installed) {
    $i++
    $ok = if (Test-Path (Join-Path $d.FullName 'SKILL.md')) { 'SKILL.md OK' } else { 'SKILL.md 없음!' }
    Write-Host ("  {0,2}. {1,-14} {2}" -f $i, $d.Name, $ok)
}
Write-Host "  합계: $($installed.Count) / 11"
Write-Host "  voice.md : $(Test-Path $voiceDest)"
Write-Host ''
Write-Host '다음: Claude Code 를 새로 열고 /yt-script 를 입력해 목록에 뜨는지 확인하세요.' -ForegroundColor Green
Write-Host "(받은 원본은 $WorkDir 에 남겨두었습니다. 필요 없으면 지워도 됩니다.)"
