# 完整评分母球摆位12题

来自用户对open12的反馈：母球贴库/过近，原排序仅角度＋球形差异。新研究管线按完整舒适分优选母球。生产代码不改；目标球取消固定位置区域，保留两袋型、三直打角度档、每档两题。

bankComfort适配：distance调用生产ShotComfortScore.evaluate；space同生产公式、输入实际母球来向；angle同生产距离衰减、输入实际碰撞切角与目标球全程路径长度；total保持0.5×min＋0.5×几何平均。生成预筛使用理想方向和两段长度，物理后重算并要求distance>=85、space>=85、total>=70、bankcut<=35。按生成total降序，只有同分才按球形差异排序；实际分不满足就拒绝或尝试下一杆速。不是成功率或全局最高实测分证明。

每袋口有限合法候选另可按完整直打总分取最大；跨六袋最高总分供参考，最小直打角仍单独维持>=45°。图中粉线与直打成功参考解为最小角度袋，不冒充最高总分袋的物理证明。

worker每次启动都跑12个直线夹具与生产全评分对拍、近球/贴库反例；生成后24杆独立精确事件重放及评分重算。audit.py独立复算评分、距离、变换及事件，并注入错总分/空间反例。

运行：python3 scripts/local_test_lifecycle.py run --task bank-comfort12-20261101 -- python3 research/bank-comfort12-20261101/run.py；随后audit.py、render.py。新版本保存到新目录，旧失败证据保留。设备与构建按受管入口释放回收。详tasks/BANK-COMFORT12-20261101.md。
