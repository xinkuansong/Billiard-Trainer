# 新摆法开球回放（2026-10-27）

状态：真实轨迹与桌面浏览器功能验证通过；最终HyperFrames 0.8.207检查通过（0错误，保留局部SVG及科学展示的非阻断提示）。供用户评阅，生产未修改，物理与研究引擎不变。

复用前阵心播放器，改为E/gate50全阵对比、标记两角球。五副：102000首副（默认，不按效果选）、102116改善组中位、102197配对差中位、102069最大改善、102195最大退化。选样规则见selection.json，不能代表300副总体。

补录10次saveFrames，rack/board/contacts/duration/spinTail/samples/eventTrace/initialCueVelocity/parameters/status/termination/playbackEnd与原研究逐字段完全一致。640个sample状态对拍最大位置误差1.13e−7m、速度误差4.84e−7m/s；终点最大误差1.97e−7m。每份回放16条轨迹，球号从canonicalNames的槽10/14映射，参数/实际初速度配对相同。按原滑动/滚动公式补平移，不重新计算碰撞；2D不表现自转，袋口外观简化。

受管运行1de1d5c8560b40809642c72ff7579e38成功并reclaimed，worker/shutdown均0，未安装App，租约释放、证据保留。物理/摆球绑定SHA不变，同期其他生产文件变化另记capture-verification.json。源research/rack-variance-playback-20261027；产物output/rack-variance-playback-20261027。

浏览器实测：5样本切换并复位；5ms角球读数与固定采样一致；20ms跳转；慢放启动；停稳与落袋状态；全程进度1000/10000跳到0.814s；截图browser-proof.png。新页面保留供评阅。手机/iPad浏览器、原生App、真机与用户认可未验。

本轮是既有研究回放局部修改，完整TP01–TP36差异沿用RACK-FRONT-PLAYBACK-20261027.md。复核TP02真实比例、TP04方案/样本真实状态、TP22从单前球改两角球轨迹圈、TP23原100ms局部定格、TP24角球实时速度和整阵固定方差、TP25只读回放、TP29原生轨迹消费不改物理、TP30暂停/隐藏生命周期、TP35桌面数据/交互与视觉证据、TP36本卡/进度。保持研究浏览器特例，无生产页面合同变化。

地址：http://127.0.0.1:52817/rack-variance-playback-20261027/player.html。复用旧output静态服务；旧回放不覆盖，服务保持供评阅。保持原白底黑字球号；局部视图隐藏球心已离开取景边界的球，修复越界球号露出/对比度问题；全桌轨迹不变。HyperFrames初轮结果另存check-initial.json/check-before-style.json，不将旧失败当通过。

最终HTTP五个文件与磁盘逐字节一致；脚本编译、git diff --check、verify-doc-size通过。页面已markDeliverable，保留首副0.814s完整开球视图，点击从头播放即可重新观看。
