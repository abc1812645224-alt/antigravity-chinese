$ErrorActionPreference = "Stop"

$TaskName = "AntigravityChinesePatch"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Antigravity 中文汉化脚本已停止，并已移除计划任务。"
} else {
  Write-Host "未找到 Antigravity 中文汉化计划任务，无需卸载。"
}
