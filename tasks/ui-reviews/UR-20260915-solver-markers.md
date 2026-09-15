# 翻袋解球 / 颗星解球：吃库标记移除与改名

用户要求：去掉吃库特殊标记，按常规轨迹显示，两个工具分别改称「翻袋解球」「颗星解球」。

## 实现

两页 drawSolution 删除独立添加的金色圆点与库面短法线，继续消费共享 TrajectoryRenderer.positionPlay；求解物理、常规轨迹分档与玩法不变。入口、导航标题、原理说明及既有 UI 测试中的名称同步。

## 功能验证

iPhone 17 Pro / iOS 26.3，S2_ShotPagesLayoutUITests 的 testV63BankCameraModes、testV63ReflectionCameraModes：修改前和修改后各 2 项，均 0 失败。覆盖入口、下一解、2D/3D 往返、观察、击打、自由模式与上一杆。最终源码由该 test 流程重新编译。verify-gate 通过。

## 视觉审查

同一模拟器、默认球形、第二条解、深色及「轨迹·全」状态比较前后 2D 原图；修改后两页的 2D / 3D 全桌原图均已打开检查。金点与短法线消失，常规线条仍显示；新标题完整显示，目标改动范围未发现新增视觉问题。

截图及日志：`output/solver-markers-20260915/`，before/ 为修改前两页，after/ 为修改后截图，before-test.log / after-test.log 为实际执行记录。参考用户截图为不同台呢和局部裁切，不作为相同画面像素对照。

未验证：本次真机安装、浅色与全设备矩阵。未提交发布。
