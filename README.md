# github-trending-daily-cn

让 AI 每天替你读一遍 GitHub Trending 上各仓库的 README，判断哪些值得看、要注意什么，输出一份中文日报（Markdown）。

流程：抓取 Trending 榜单 → 用 GitHub 公开 API 补 README 片段、创建日期、协议 → 交给 `codex exec` 写点评 → 可选用 cron 每天定时运行。

示例输出见 [examples/](examples/)，常见问题见 [docs/troubleshooting.md](docs/troubleshooting.md)。

## 实测环境（2026-10-12）

| 组件 | 实测版本 | 说明 |
|---|---|---|
| codex-cli | 0.162.1 | `npm i -g @openai/codex@0.162.1` |
| Node.js | v20.19.2 | npm 包声明 `node >=16`；AI Code With 文档要求 18+，建议按 18+ 准备 |
| bash | 5.2.37 | macOS 自带 bash 3.2 未实测 |
| python3 | 3.13.5 | 只用标准库 |
| curl | 8.14.1 | |
| 模型 | gpt-5.6-sol | 通过 AI Code With 的 Responses 接口 |

只在 Linux 上跑过。

## 文件

```
trending-daily.sh        主脚本：抓取 -> 组 JSON -> codex exec 写日报
prompt.md                提示词模板，{{DAY}} 会被替换成日期，JSON 接在末尾
codex-home/config.toml   只给本脚本用的 Codex 配置（Key 走环境变量）
.env.example             ~/.aicw_env 的格式示例（不要把真 Key 放进仓库）
crontab.example          cron 配置示例
logs/                    运行日志（cron 的重定向需要这个目录事先存在）
docs/troubleshooting.md  常见问题排查
examples/                一次真实运行的日报和终端输出
```

运行后会生成 `data/`（抓到的 HTML 和 JSON）、`reports/`（日报）、`logs/YYYY-MM-DD.jsonl`（codex 事件流，含 token 用量），均已在 `.gitignore` 里。同一天重跑会覆盖当天文件。

## 快速开始

```bash
npm i -g @openai/codex@0.162.1
codex --version                      # 应输出 codex-cli 0.162.1

git clone https://github.com/aicodewith-team/github-trending-daily-cn.git ~/trending-daily
cd ~/trending-daily
```

保存 Key（只能在 bash 里执行；输入时不回显，不进 history）：

```bash
(
  umask 077
  read -rsp "粘贴 AICW_API_KEY 后回车: " k; echo
  printf 'export AICW_API_KEY=%q\n' "$k" > ~/.aicw_env
  unset k
)
chmod 600 ~/.aicw_env
ls -l ~/.aicw_env                    # 应为 -rw-------
```

zsh（macOS 默认终端）：

```zsh
( umask 077; read -rs 'k?粘贴 AICW_API_KEY 后回车: '; echo; printf 'export AICW_API_KEY=%q\n' "$k" > ~/.aicw_env ); chmod 600 ~/.aicw_env
```

Key 只含字母、数字、`-`、`_`、`.` 时，两种写法生成的文件都能被 cron 用的 `/bin/sh` 读取。

手动跑一次：

```bash
. ~/.aicw_env && ./trending-daily.sh
```

正常输出类似：

```
抓到 8 个仓库，README 成功 8 个
Reading additional input from stdin...
"usage":{"input_tokens":20626,"cached_input_tokens":12544,"cache_write_input_tokens":0,"output_tokens":2370,"reasoning_output_tokens":91}
日报已生成：reports/2026-10-12.md
```

## 定时运行

见 `crontab.example`。要点：

1. `which codex`、`which node` 查绝对路径；codex 路径填进 `CODEX_BIN=`，node 所在目录放进 crontab 的 `PATH=`。
2. cron 不读 `.bashrc`，Key 靠 `. $HOME/.aicw_env` 加载。
3. cron 按机器本地时区；UTC 服务器上北京时间 8 点写 `0 0 * * *`。
4. macOS 上 cron 需要“完全磁盘访问”权限，官方更推荐 launchd（未实测）。

## 安全

- `codex exec` 以 `--sandbox read-only` 运行，不能写文件、不能联网；抓取在 Codex 外面完成。
- README 是外部内容，可能含提示注入。自己看问题不大，自动推送到群之前建议人工过一眼。
- `~/.aicw_env` 是明文文件，建议给本脚本单独建 Key，泄露后直接吊销。调试时不要 `set -x`，不要 `env > log`。
- GitHub 公开 API 未认证时每小时 60 次，每次运行最多 20 次。

## 许可

代码：MIT（见 LICENSE）。生成的日报内容转述自各仓库 README，版权归原作者；点评由 AI 生成，使用前请自行核对。
