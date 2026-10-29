# GaiaBit Shelter Twin｜系統管理後台

版本：1.0.0 Admin Prototype（2026-10-29）  
對照來源：《GaiaBit Shelter Twin 完整系統建置計畫書》（19 頁）與使用者提供的前台／後台 UI/UX 示意圖。

## 交付檔案（固定四個）

1. `index.html`：單頁後台，HTML + CSS + JavaScript，包含 Three.js CDN 3D 場景。
2. `config.json`：示範場域資料與情境參數（初始資料交換範本）。
3. `schema.sql`：新建 Supabase 專案的 PostgreSQL 資料表、索引與基礎 RLS。
4. `README.md`：操作、部署、限制及後續整合指引。

## 立即開始

- 直接雙擊 `index.html`，或上傳 GitHub 後透過 Vercel（Framework Preset: Other）部署；正常載入 3D 需要存取 Three.js CDN。
- 預設示範場域嵌入 HTML，**不需要**先配置 Supabase 即可操作。`config.json` 是資料範本；網站目前不會在載入時自動 fetch 該檔。
- 使用「場域與模型」編輯區域名稱、位置、長寬和容量；可拖曳 2D 區塊，切換可旋轉的 3D 概念模型。
- 在「設備與 AI」「動物與人員」「班表及任務」可修改示範資料。
- 「情境實驗室」調整攝影機、人力、AI、路線等假設，執行估算；「報告匯出」可下載報告 JSON。
- 所有本機修改儲存於瀏覽器 `localStorage`，清除網站資料或換瀏覽器即可能消失。請定期從「系統及連線」下載 JSON 備份。

## 依計畫書建置的功能與限制

| 規格 | 本版狀態 |
| --- | --- |
| 管理後台總覽、任務、設備、犬貓、版本、風險 | 已有可操作 Demo |
| 簡易 2D 畫面及區域拖曳 | 已有 |
| 可旋轉、縮放、即時反映區域的 L1 3D 概念模型 | 已有（需網路） |
| 本機 CRUD 與 JSON 備份 | 已有（僅部分資料型別） |
| 固定基準公式的情境估算／JSON 報告 | 已有（僅概念估算） |
| 多格式檔案選擇及部分圖片/PDF 預覽 | 已有（不代表解析或 3D 轉換） |
| JPG/PNG/PDF/AI/DXF/DWG/IFC 自動轉 3D | **未完成**；需伺服器轉檔、幾何解析、比例校正、人工覆核 |
| 牆門及障礙編輯、導航網格、動線合規規則 | **未完成** |
| 經校準的 DES/ABM 與大量重複模擬 | **未完成**；目前僅簡化公式 |
| 真實 AI 偵測、攝影機直播與影像調用 | **未完成** |
| Supabase Auth 登入、雲端 CRUD 與檔案 Storage | **未完成**；提供安全的 SQL 起始結構 |
| 角色實際授權、正式稽核與備份 | **未完成**；UI 僅展示預期角色 |
| 正式 XLSX/PDF 引擎與 PDF 報表排版 | **未完成**；目前 JSON 匯出與瀏覽器列印 |

## 模擬計算說明

示範引擎使用固定公式，**不是**經驗證的實際效果：

- 監測覆蓋率 = `min(92%, cameras / 12 × 65%)`；此處的 65% 僅為概念假設，**不是**幾何遮蔽與 AI 辨識的實際有效面積。
- AI 偵測發現基準設 8 分鐘，非 AI 為 45 分鐘，並以未覆蓋比例加算示意時間。
- 完整事件回應時間 = 發現 + 通知 + 確認 + 路程 + 處置。當前通知、確認與處置時間是 Demo 常數。
- 工作負荷 = 18 小時每日工作需求 ÷ (人員 × 7 小時有效工時)；人力為 0 時顯示缺值。
- 動線優化僅採用示意折減係數，**不會產生真正符合隔離／消毒規則的路徑**。
- 所有數字須標示「示範／推估」，正式合作報告必須另行量測、校準、固定基準條件與不確定性分析。

## GitHub → Vercel → Supabase（新專案流程）

### 1. GitHub

建立 Private repository，例如 `gaiabit-shelter-twin-admin`，直接上傳這四個檔案至儲存庫根目錄。

### 2. Vercel

New Project → Import GitHub Repository → Framework Preset **Other** → Deploy。因根目錄含 `index.html`，可部署靜態網站。**不要**覆寫原本正常的 Shelter Twin 專案，建議新建 `gaiabit-shelter-twin-admin`。

### 3. Supabase

在正確的專用 Supabase Project 中開啟 SQL Editor，確認 SQL 內容後執行 `schema.sql`，建立 `twin_` 開頭的各表。資料庫內建 RLS，初期僅限場域 owner `auth.uid()` 操作。這不等於前端已接上登入和 CRUD。

不要將 `service_role`、`sb_secret_...`、資料庫密碼寫入 HTML、config.json 或 GitHub。建議正式系統由 Supabase Auth 驗證身分，實施依場域與功能區分之 RLS，所有稽核與高權限操作透過受控伺服器端執行。

**注意**：目前「系統及連線」只是記錄公開 API URL 與 publishable key 的介面，**沒有真正連線功能**；UI 會明示此點，避免誤判雲端已同步。若要上線使用，下一迭代需接 Auth + REST/RPC、真實模型檔 Storage 和授權控管。

## 下一階段研發優先順序

1. Supabase Auth + 實際場域 CRUD、owner 成員與 RLS 驗證、多場域隔離。
2. 原始檔私有上傳、真實圖片/PDF 預覽、轉檔工作佇列與 MIME 安全檢查。
3. 空間編輯器：牆門、比例尺、房間閉合、通道/隔離約束、版本比較。
4. 可靠的 2D→3D 幾何建模與人工檢查；GLB 模型轉換及分層載入。
5. 時間獨立的 DES/ABM、任務資源與技能限制、A* 路徑引擎、事件重播與可重現結果。
6. 真實 IoT、AI 與診斷外之行為提示、模型校準、完整報告與風險治理。

## 使用限制與資料保護

此程式為前端可操作原型，**不是**已驗證的智慧收容所正式管理系統，不能用作醫療診斷、實際人力裁撤或防疫規則替代品。展示資料均為合成示範，請勿匯入真實個資、醫療紀錄、私密圖面或監視影像。模型比例、動線、AI 誤報與經濟效益在現場實測之前不能視為真實成果。


## SQL 版本更新（2026-10-29）

如先前執行過使用 `twin_*` 與 `facility_id` 的舊版資料庫，請改用本包的 `schema.sql`。新版改用 `stwin_*` 資料表（例如 `stwin_shelters`、`stwin_zones`），避免 `shelter_id` 欄位與舊結構衝突；不會刪除或更改舊版資料表。重新執行新版 SQL 不會因重複 policy 名稱而失敗。注意：HTML 目前仍以本機展示資料操作，尚未連接 Supabase。
