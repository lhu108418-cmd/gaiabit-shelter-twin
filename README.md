# GaiaBit Shelter Twin — 收容所數位孿生模擬中心

## 交付檔案（固定四份）
- `index.html`：單頁網站，含 3D 場域、鏡頭、人員、路線、熱區及情境模擬。
- `config.json`：示範場域配置、犬貓數量、設備數量和模型假設。
- `schema.sql`：Supabase PostgreSQL 資料表、索引與 Row Level Security。
- `README.md`：這份建置／操作說明。

> 注意：這是可操作的**展示原型**。畫面上全部數值及事件均是示範或計算假設，並非真實收容所監測、AI 辨識結果，也不代表實際導入後會達成的效益。3D 使用 Three.js CDN，首次開啟需要網路。當前不需要 Supabase 才能運作。

## 從零部署：1. GitHub → 2. Vercel → 3. Supabase

### 1. GitHub
1. 登入 https://github.com ，右上角 `+` → `New repository`。
2. Repository name 填 `gaiabit-shelter-twin`，建議選 `Private`，按 `Create repository`。
3. 選 `Add file` → `Upload files`，**解壓縮 ZIP 後**將這四個檔案（不是 ZIP 本身）拖到儲存庫根目錄。
4. 按 `Commit changes`。確認 GitHub 最上層可直接看到 `index.html`，不要多一層資料夾。

### 2. Vercel
1. 登入 https://vercel.com/new ，透過 GitHub 登入並授權該儲存庫。
2. `Import` `gaiabit-shelter-twin`。
3. Framework Preset 選 `Other`。Root Directory 選 `./`。此版沒有 build 指令、沒有 npm 依賴，保持 Build Command 為空，Output Directory 留預設即可。
4. 按 `Deploy`。完成後打開 Vercel 提供的 `*.vercel.app` 網址。
5. 畫面應顯示 3D 場域與左右側資料。轉動 3D、調整右側滑桿、測試 JSON 匯入匯出。
6. 若網站顯示 404，檢查 `index.html` 是否位於 Repository 根目錄，以及 Vercel Root Directory 是否指向同一層。

### 3. Supabase
1. 登入 https://supabase.com/dashboard，`New project`，填名稱，例如 `gaiabit-shelter-twin`。密碼請保管好。
2. 進入 `SQL Editor` → `New query`，貼上完整 `schema.sql`，按 `Run`。
3. 進入 `Table Editor`，應出現 `twin_facilities`、`twin_zones`、`twin_devices`、`twin_animals`、`twin_staff_shifts`、`twin_events`、`twin_daily_metrics`、`twin_simulations`、`twin_memberships`。
4. 已啟用 RLS：未登入者**無權**讀取以上表格。不要停用 RLS，也不要將 Supabase `service_role` / secret key 放入 `index.html` 或 `config.json`。
5. Supabase → `Project Settings` / `API Keys` 可查看 Project URL 和 publishable key。這些僅在後續實作登入與資料 CRUD 時使用；目前原型**未連線資料庫**，不需要設定任何 Vercel 環境變數，`config.json` 中的 supabase 欄位保留空值即可。

## 操作方式
- 3D：拖曳旋轉，滾輪縮放；點擊建物可顯示區域名稱與犬貓數。
- Overlays：切換鏡頭、人員、熱區、動線。
- Scenario Lab：調整新增鏡頭、人力、AI 採用率、曝光倍數；下方 KPI 即時重算。
- 匯出報告 JSON：保存目前情境結果。
- 載入 `config.json`：從 Vercel 網址載入同目錄的場域定義，更新 3D。
- 匯入自訂 JSON：本機選檔。瀏覽器直接用 `file://` 開啟時請用此方式，因為部分瀏覽器不允許 `fetch('./config.json')`。
- 修改場域：可在 JSON 修改 `zones` 中每棟建築的 `x`、`z`、`width`、`depth`、`count` 等，修改後重新載入。座標是示意公尺尺度，尚未具備平面圖解析或建模功能。

## 真實導入需要蒐集的資料
1. 場域：按比例的平面圖、建築外框／走道尺寸、區域用途、障礙與門禁。
2. 動物：各舍容量、實際犬貓數、出入舍事件、照護與醫療記錄。
3. 人員：排班、路線、工作時間、每日巡檢和任務完成時刻。
4. 設備：鏡頭位置／視角／在線率、感測器數值、投食器回報、網路拓樸。
5. 成效：至少一段導入前及後的同口徑量測，例：異常從發生到被發現的時間、人工工時、觀看／詢問／預約／認養的轉換。分開記錄真實值、估計值和模型假設。

## 重要限制與接續開發
- 目前模型使用簡化比例，不是經驗證的因果推估。滑桿產生的「節省比例」只能展示情境，不宜對外宣稱成績。
- 目前所有 3D 建物為程式自動生成的示意方塊，不是上傳平面圖自動生成 3D；也尚無照片、影音或攝影機影像串流。
- `schema.sql` 建立可供後續使用的資料結構，但 `index.html` 現階段尚未實作登入、讀寫 Supabase、即時訂閱。若要上線使用真實資料，需補上登入、後台欄位管理、事件上報 API、資料權限分工、前後期統計、視覺化驗證與稽核。
- 避免以個體動物健康分數取代獸醫判斷，避免以模擬數值代替臨床與實際營運觀測。
