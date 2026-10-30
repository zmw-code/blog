# 发布流程（给自己看的）

> 这份是给**人**看的操作说明，打开仓库就能查，不用去翻 agent 的目录。
> 给 agent 看的那份在 `~/.workbuddy/skills/publish-tech-article/SKILL.md`。
> 两边会有重复内容 —— 受众不同，别合并。

---

## 这个仓库是干什么的

所有技术文章的**原稿归档**，也是一切内容的锚点。

- 每篇文章先在这里落地 → **commit 时间戳 = 首发时间**（平台的时间能改，commit 改不了）
- 然后再分发到 掘金 / CSDN / 知乎
- 平台会限流、删文、封号；这里不会

## 目录约定

| 路径 | 放什么 |
| --- | --- |
| `posts/` | 文章，命名 `YYYY-MM-DD-英文短名.md` |
| `scripts/` | 文章配套的、读者可直接下载的脚本 |
| `README.md` | 文章目录 |
| `WORKFLOW.md` | 本文件 |

⚠️ **文章文件名必须英文**。中文名会被 URL 转义成一长串 `%E8%AE%BE...`，贴出去没法看。
中文标题写在文件内容的第一个 `# ` 里。

---

## 发一篇新文章

在自己终端里（Git Bash）跑一条命令：

```bash
~/.workbuddy/skills/publish-tech-article/scripts/push-post.sh /d/Projects/blog 原稿.md 英文slug
```

它会依次：查 HTML 实体 / 查代码块围栏是否配对 → 复制到 `posts/` → commit → push → 打印两种链接。

⚠️ **别让 agent 代跑这条**。工具通道会把中文 commit message 读成乱码，commit 历史就毁了。
（要 agent 代跑，就只让它用 ASCII 写 message。）

---

## 铁律：顺序不能反

**先归档 → 再发平台。**

反例（真实踩过）：adb 那篇是先发掘金（10-13）、两天后才补 GitHub（10-16）。结果首发时间戳归了掘金，不是自己手里。

---

## 两种链接，别混

| 用途 | 形式 | 特点 |
| --- | --- | --- |
| 给读者的回链 | `.../blob/main/posts/xxx.md` | 跟着以后改稿一起更新 |
| 当首发证据 | `.../blob/<完整 commit SHA>/posts/xxx.md` | 冻结在那一刻，内容永不漂移 |

**在 GitHub 网页上打开文件后按 `y` 键**，URL 会自动从 `main` 换成完整 SHA —— 这是拿冻结链接最快的办法。

---

## 回链写在哪

**放文章开头，不是文末。**

理由：搬运号要删回链，就得动文章开头，很显眼；放文末被顺手砍掉最省事。

一行模板：

```
本文原文归档：<blob/main 链接>
```

---

## 各平台要点

| 平台 | 怎么发 | 已知的坑 |
| --- | --- | --- |
| **掘金**（主阵地） | 编辑器右上角**切 Markdown 模式**再粘全文 | 没有「原创」勾选项，别找了；不会吞 CSDN 外链（会包一层自家跳转）；分类选最贴近的；标签 2~4 个；摘要 ≤100 字 |
| **CSDN**（流量入口） | 直接粘 Markdown | 生态乱、文章会被搬运 —— 这是换百度长尾收录的代价 |
| **知乎**（引流） | **别单发文章**：搜相关问题，在问题下写回答，末尾贴链接 | 不支持 Markdown，表格和代码块要重排 |
| **少数派** | 暂不投 | 想拿稿酬要签作者协议 + 提供收款信息 = 实名，与匿名路线冲突；《风格指南》明令禁止反语、讽刺、影射 |

**更稳的做法**：掘金/CSDN 用「跳转式」结构 —— 常见问题只给链接不重写，自己的方案写详细步骤。

---

## 本机两个坑

1. **bash 通道的写盘是虚拟化的**（这里跑的是 WorkBuddy 自带的 PortableGit，不是 `D:\Git`）。
   `git clone` 会打印 "Cloning into ..." 但目录实际不存在。
   ⇒ 真正要落盘的 git 操作，走 **PowerShell**。
2. **中文 commit message 在工具通道里会变成乱码**（实测看到过 `feat(post): 琛?adb...`）。
   ⇒ 要么自己在终端跑，要么让 agent 只写 ASCII message。

## 身份与隐私

- commit 作者邮箱已设为 `233108713+zmw-code@users.noreply.github.com`，**不会泄露 QQ 邮箱**
- GitHub 端已开 "Keep my email addresses private"
- ⚠️ 2026-10-16 之前的老仓库（QuickMove / repo-buddy / RogueMonitor）里的历史 commit 仍带旧邮箱，改不掉，也不必重写历史
