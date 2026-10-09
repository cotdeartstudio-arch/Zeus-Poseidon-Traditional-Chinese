# 目前實際使用文字

此目錄以 V2.2 實際遊戲資料匯出為基礎，顯示選單已對應 v2.3 基礎漢化包的原版解析度。選裝 HD／2K 後會套用另一組顯示選單名稱。

- `Zeus_Text.eng.json`：主遊戲文字，依 group/index 對應。
- `Zeus_Editor_Text.eng.json`：編輯器文字，依 group/index 對應。
- `Zeus_MM.eng.json`：訊息及劇情，依 id/field 對應。
- `Model/`、`Adventures/`：事件與獨立冒險文字的 UTF-8 查閱版本。
- `encoding.json`：遊戲使用的中文字碼對照。
- 原文欄位與部分技術字串保留英文，不代表全部會出現在遊戲畫面。

JSON 與 UTF-8 文字供查閱及校對，不能直接覆蓋遊戲的 .eng 或 .txt。安裝用資料是 patch/payload 的配套差異檔。
