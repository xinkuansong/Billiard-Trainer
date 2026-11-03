# K球／解球参考轨迹纠正 · 原生复核

现行需求：[DR-452 r3／DR-457 r2](../table-page-adaptation/KICK-KBALL-REFERENCE-CORRECTION-20261101.md)。用户明确纠正为K球保留、解球取消。测试合同随新要求更正；不删除实际提交、重打、额度与保存失败断言。

本轮只改变两个页面的参考生成／显示门控，复用原灰色虚线与图例。字号、球桌布局、球库及主按钮保持原组件；不做视觉改版。TP22按业务调整，TP09/15/16/25/26继承；TP35原生功能与原图分别核对。

执行环境：Mac mini，Xcode26.2，iPhone SE3／iOS17.0，独立FIFO任务`kick-kball-reference-correction-20261101-r1`。快照`f5f363bf1398b100b85f650c5477a3155fe38a356710f54dc0637d4ce9f685b9`，取自受管私有源码副本；复制前后校验共享源码未漂移，私有目录独占冻结。本地临时复制目录已由生命周期回收，来源清单留在`output/local-test-runs/e623a8d158d94431a482695243786857/evidence/`。

改前：引用同日历史SE原图（见页面卡）；本轮改前六文件原字节另存。改后25张原始附件已回传并导出，其中与本轮相关的11张已逐张打开核对。历史原图不标为本轮新拍。

本地Swift语法、verify-gate（FAIL0）、verify-doc-size通过。真机、iPad、全App回归与用户体验未验；未提交发布。

## 结果

- 构建成功，14项通过／0失败／0跳过：8项K球逻辑、2项解球宿主逻辑、两页各2项UI。原始摘要：`output/kick-kball-reference-correction-20261101/remote/evidence/test-summary.json`。
- 逐张核对11张：两页2D/3D新题共4张、两页2D/3D重打共4张、两页换题共2张及解球3D测量1张。K球新题有灰色参考及图例；解球新题无中杆预测，白色短瞄准线仍在；两页重打均见白色实际线；换题按各自合同恢复；测量工具仍可用。未见本轮引入的文字截断、球库或仪表布局变化。不同题目截图不作为逐像素等价证明。
- 六个改动源码／测试文件SHA逐一匹配测试快照和当前工作区；未改物理、题库、计分、布局及共享颜色。
- `xcresulttool export attachments`使本地`database.sqlite3`哈希变化，首次complete被完整性校验拒绝；从远端回传该数据库原件后重新校验，保留原测试结果和全部导出截图，不放宽校验。

截图目录：`output/kick-kball-reference-correction-20261101/images/`，保留原GUID与manifest，短名文件仅原字节副本。

![K球首答前参考](../../output/kick-kball-reference-correction-20261101/images/kBall-2D-before-answer.png)
![解球新题无预测](../../output/kick-kball-reference-correction-20261101/images/kick-no-baseline-2D.png)

下一步为用户在实际设备体验；本轮实现和定向模拟器验证完成，不宣称真机、iPad或全App回归完成。

收尾：远端complete校验通过并回收本轮build/source及无引用快照；本地受管复制目录已回收，测试证据与原图保留。未安装真机、未提交或发布。
