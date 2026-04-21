# 财富密码词根清单

这是出海工具站方向最常见的高频需求词根。每个词根背后都藏着几十到上百个候选关键词。

**怎么用**：挑一个词根，去 Semrush Keyword Magic Tool 输入，筛选条件 `KD 0-29 + CPC ≥ $0.1 + Volume 200-10000`，导出 CSV，用 `scripts/kdroi.py` 排序。

**不是穷举**：列表里是最常用的一批，用户感兴趣的领域可以自己扩展。关键是理解"词根 → 扩展词 → 用户搜索意图"这条链。

## 核心 18 个词根（来自原文）

| 词根 | 常见扩展方向 | 典型搜索意图 |
|---|---|---|
| **Generator** | Password / QR Code / AI Image / Invoice / Meme / Logo / Name / AI Headshot | 用户想生成一个东西 |
| **Converter** | PDF to Word / Image / Currency / Unit / Video / Audio | 格式互转 |
| **Calculator** | Mortgage / Age / Salary / BMI / Tax / Pregnancy / Loan | 计算数值 |
| **Editor** | Photo / Video / PDF / Text / SVG / Code | 编辑内容 |
| **Maker** | Logo / Meme / Resume / Sticker / Gift / Collage | 从无到有做一个 |
| **Checker** | Grammar / Plagiarism / Backlink / SSL / Domain / Password | 校验某个东西 |
| **Detector** | AI Content / Plagiarism / Object / Face / Background Remover | 检测/识别 |
| **Builder** | Website / Resume / Form / App / Chatbot / Landing Page | 搭建一个东西 |
| **Template** | Resume / Invoice / Contract / Email / Presentation | 模板下载 |
| **Downloader** | YouTube / Instagram / TikTok / Twitter / Facebook Video | 下载平台内容 |
| **Analyzer** | Data / SEO / Text / Sentiment / Keyword | 分析数据 |
| **Optimizer** | Image / SEO / PDF / Video Compressor | 优化文件/内容 |
| **Tracker** | Package / Fitness / Habit / Expense / Sleep / Flight | 追踪状态 |
| **Planner** | Meal / Trip / Wedding / Study / Budget | 规划安排 |
| **Assistant** | AI / Writing / Email / Code / Research | AI 助手型 |
| **Simulator** | Mortgage / Investment / Interview / Physics | 模拟场景 |
| **Scraper** | Web / Email / Phone / Product / LinkedIn | 批量抓取数据 |
| **Comparator** | Product / Price / Car / Phone | 对比工具 |

## 补充可用词根（常见扩展）

| 词根 | 用途方向 |
|---|---|
| **Finder** | Domain / Name / File / Song / Job |
| **Remover** | Background / Watermark / Noise / Object |
| **Formatter** | JSON / XML / Code / SQL / Text |
| **Summarizer** | Article / Video / PDF / Meeting |
| **Translator** | Language / Code / Emoji |
| **Compressor** | Image / PDF / Video / Audio |
| **Validator** | Email / JSON / Credit Card / VAT |
| **Randomizer** | Name / Number / Color / Word |
| **Counter** | Word / Character / Click |
| **Viewer** | PDF / SVG / JSON / Code / 3D |
| **Cropper** | Image / Video / PDF |
| **Resizer** | Image / Video / File |
| **Mixer** | Color / Audio / Image |
| **Scheduler** | Social Media / Email / Task |
| **Reminder** | Calendar / Medicine / Bill |

## 实操路径（对每个词根）

1. **扩展**：Semrush Keyword Magic Tool → 输入词根（如 "Generator"）
2. **筛选**：
   - KD: 0 – 29
   - Volume: 200 – 10,000
   - CPC: ≥ $0.1
   - 排除 "near me"
3. **导出**：Export → CSV
4. **打分**：
   ```bash
   python3 ~/.claude/skills/niche-finder/scripts/kdroi.py path/to/file.csv
   ```
5. **看 Top 10**：脚本自动按 KDRoi 降序输出 Top 20 的 Markdown 表格
6. **验证**：对 Top 3-5 逐个走四步验证（见 `validation.md`）

## 为什么词根法最适合新手

- **有边界**：一个词根能挖出几十到几百个候选，筛选空间够大
- **意图明确**：用户搜 "XX Generator" 就是要生成 XX，不用猜
- **变现清晰**：工具类关键词通常 CPC 中等（$0.3–$3），Adsense + 会员都能走
- **可自动化**：大部分工具可以用 AI / API 快速实现，适合独立开发
- **可量产**：练手阶段，一个词根做 1-2 个站；熟练后批量扩展

## 反例（词根法不适合的方向）

- **高 CPC 但极高 KD**：金融、法律、医疗、B2B SaaS — CPC 能到 $10+，但 KD 普遍 60+，新手打不进
- **强季节词根**：`Christmas XXX`、`Halloween XXX` 一年只有 1-2 个月有流量
- **纯信息查询**：`What is XXX`、`XXX meaning` — 变现能力差，CPC 通常 < $0.05
