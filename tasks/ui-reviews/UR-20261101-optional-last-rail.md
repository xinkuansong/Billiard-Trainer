# 解球／K球末库可选（DR-456）

现行合同见 `tasks/table-page-adaptation/KICK-KBALL-FEEDBACK-20261031.md` 第六轮。用户最新裁定：末块内侧四边完整白虚线、不加块内文字；一库解球仍必经，不画框。

功能：35项逻辑通过（解球21、K球练习8、K球库6），含463解球固定参考生产重放、K球一至三库入库前／出库后参考、完整／N−1前缀、无碰后库、错序／多库／少库、1库区别及旧记录可读不可混版续练。结果 `output/local-test-runs/09d6f11e513f4bc5bdb9c70249979df7/evidence/tests.xcresult`；该包顶部是过程版三边框，不能作为最终四边外观证据。

视觉：最终SE3/iOS17.0 `output/optional-last-rail-20261101/se-r2.xcresult` 两项UI通过。已逐张打开`se-images/`四张关键原图：K球两库（末块完整白框、侧栏短文案无省略）、四库解球2D／3D（仅末块白框、数字与同径下沿保持）、一库解球（无框）。映射见manifest／named-images。iPad Pro11/iOS26.3.1同包两项UI通过（ipad-final.xcresult）；六张原图逐张已审：K球横竖2D、解球四库竖2D两张／横3D与一库无框。未单独拍四库横2D；既有桌面取景未改。最终共4项UI，0失败。gate-final及文档体积检查通过。

首轮35逻辑＋2UI通过后，原图发现K球侧栏追加括号说明造成省略号（FL-238）；恢复“要求：两库”，信息用白框和AX表达。用户由三边改四边的两次过程包保留，最终只认se-r2与最终iPad包。

未验证：真机、VoiceOver实际朗读、分屏／缩窗、全App回归；未改题库／物理引擎，未发布或安装真机。
