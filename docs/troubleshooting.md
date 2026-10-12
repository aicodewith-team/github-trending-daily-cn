# 常见问题排查

教程正文只写了两个最常见的问题（cron 下找不到 `codex`、cron 下读不到 Key）。其余问题记录在这里，每条标注了来源：**实测**＝作者运行时实际遇到；**推断**＝根据代码或文档推出，未实际遇到。

## 1. cron 下 `codex: command not found`（实测）

cron 的 PATH 只有 `/usr/bin:/bin`，没有 npm 全局目录。用 `which codex` 查绝对路径，在 crontab 里写 `CODEX_BIN=/绝对路径/codex`。

不要用 `$(npm prefix -g)` 自动推算：在 cron 的空环境里它可能算出 `/usr/local`，与交互 shell 不同（例如交互 shell 设置了 `NPM_CONFIG_PREFIX` 时）。

## 2. 报错「请先设置 AICW_API_KEY」（实测）

cron 不读 `~/.bashrc`。crontab 那一行要先 `. $HOME/.aicw_env`。脚本在调用模型之前就会检查并退出，不会产生费用。

## 3. `env: node: No such file or directory`（推断）

codex 的入口脚本是 `#!/usr/bin/env node`。node 装在 nvm、Homebrew（`/opt/homebrew/bin`）等目录时，cron 里找不到它。把 `dirname "$(which node)"` 的结果加到 crontab 中 `PATH=` 行的最前面。

## 4. 日志里有 `ERROR codex_core::util: OutputTextDelta without active item`（实测）

codex-cli 0.162.1 两次运行中出现过，退出码为 0，日报完整，可以忽略。

## 5. 某次运行特别慢（实测）

一次运行用了 153 秒（其他为 40～90 秒），事件日志显示中途断流一次后 Codex 自动重连。无需处理。

## 6. 日报里写「README 获取失败」（推断）

GitHub 公开 API 未认证时每小时限 60 次，脚本每次运行最多 20 次（每个仓库 2 次）。调试时短时间连跑几遍就可能超限。等一小时再跑即可。

## 7. 协议显示为 `NOASSERTION` 或「协议未明确」（实测）

GitHub API 无法识别仓库的 LICENSE 文件时返回 `NOASSERTION`（例如 pytorch）。需要准确信息时请直接看该仓库的 LICENSE。

## 8. cron.log 没有生成（推断）

crontab 里的 `>> .../logs/cron.log` 重定向在脚本执行之前由 shell 处理，`logs/` 目录必须事先存在。仓库里放了 `logs/.gitkeep`，克隆后目录就在。如果你改了安装路径，确认路径一致。

## 9. 时间不对（推断）

cron 按机器本地时区运行。用 `date` 查看时区；UTC 服务器上想在北京时间 8 点运行，写 `0 0 * * *`。

## 10. 手动运行卡住不动（实测）

`codex exec` 在 stdin 不是终端时会读取标准输入。脚本已经加了 `< /dev/null`，如果你自己改写命令，记得保留。输出中的 `Reading additional input from stdin...` 是正常提示。

## 11. 解析不到仓库（推断）

GitHub Trending 没有官方 API，脚本靠页面 HTML 结构解析。GitHub 改版后，匹配不到的条目会被跳过；一个都没解析到时脚本退出，不会调用模型。

## 12. macOS（未实测）

作者只在 Linux 上运行过。macOS 上 cron 需要给 `/usr/sbin/cron`「完全磁盘访问」权限，苹果更推荐 launchd。zsh 下保存 Key 的写法见 README。
