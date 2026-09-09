# 动作库搜索与收藏局部诊断

2026-09-08，snapshot004，专用iPhone17Pro/iOS26.2，正常游客入口，内存容器。

formal-004-library-search-favorites-001 精确方法 testLibraryEmptySearchRecoversAndFavoriteSurvivesReentry 实际1/1通过，60.959秒，make0。空收藏进入动作库；唯一无结果关键词返回空态且动作卡数量0；浏览全部动作恢复；搜索中袋直线出杆，收藏后出现取消收藏；两次进入我的收藏均找到该动作。主控目视最终重入截图，标题、动作名、收藏标记一致。四张原始PNG、实际xcresult、日志与源哈希保存在archive/quality-diagnosis/runs/formal-004-library-search-favorites-001。

只证明同一进程内正常搜索恢复与收藏重入；未验证杀进程磁盘持久化、取消收藏、全部搜索词与筛选组合。SC03从未执行更新为局部完成。
