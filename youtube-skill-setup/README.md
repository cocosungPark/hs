# YouTube agent skill 설치 (Windows)

1. 이 폴더의 `install-yt-skills.bat`, `install-yt-skills.ps1` 두 파일을 같은 폴더에 내려받기
2. `install-yt-skills.bat` 더블클릭
3. 끝나면 Claude Code 를 새로 열고 `/yt-script` 입력 → 목록에 뜨면 성공

| 하는 일 | 위치 |
|---|---|
| `skills/yt-*` 11개 복사 (커밋 a2feb21 고정) | `%USERPROFILE%\.claude\skills\` |
| `templates/voice.md` 복사 (이미 있으면 안 덮어씀) | `%USERPROFILE%\.claude\youtube\voice.md` |
| Python 3 확인 + `hookscore.py` 영어 문장 1개 채점 | 화면 출력 |
| `/yt-script` 후킹 규칙 추가 (중복 추가 안 함, 기존 파일 백업) | `%USERPROFILE%\.claude\CLAUDE.md` |

다시 실행해도 안전합니다. 기존 yt-* 스킬은 `%USERPROFILE%\.claude\yt-skills-backup\<시각>\` 으로 옮긴 뒤 새로 복사합니다.
