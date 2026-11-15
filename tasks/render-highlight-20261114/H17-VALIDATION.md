# H17验证与收尾

- R1/R2独立原生材质研究成功，分别36组和36+36组画面对照，所有原始时间戳保留。R2相机逐帧重建没有顺序平衡，不用它宣称重建收益。
- R3当前生产完整场景原生构建成功，`testNativeClothComputeReuse` 1项通过、0跳过；24组图像最大差1/255、AA/恢复零差。抬高球漏验已明确记录，并由R4补齐。
- R4真实动作原生构建成功，`testNativeClothComputeAnimation` 1项通过、0跳过；8组最大1/255、AA/恢复零差，每帧update/action各1次，编码球中心/高度与最终presentation误差0。
- 已人工式独立审查R3近景A/B、俯视原图，R4抬高球及相机/粗糙度变更原图。没有把“测试采集完成”等同画质通过。
- R4实际受测Swift文件与当前工作区一致；各原生作业`hash-after.json`均确认冻结快照和构建副本未漂移。
- 首次`verify-gate`因内嵌Metal的`texture.write`字面量触发写盘入口清单漂移而失败。已审计：写GPU纹理，不是新增文件系统API；XCTest附件仍入受管xcresult。登记后局部UI基线门禁通过。
- 最终受管门禁作业`80d60fa1c20b4ef385fd8148435ae781`：`make -f scripts/Makefile verify-gate`和`verify-doc-size`均exit0，原始日志在evidence；PROGRESS约99KB，未提高上限。
- 相关差异`git diff --check`通过，Python脚本语法解析通过。本轮未修改`QiuJi/`生产App代码；没有额外无关功能回归。
- 四轮成功实验、R3a失败、两次失败动作预检、最终动作预检及最终门禁的工作目录均由生命周期管理器回收，证据保留。没有清理其他任务目录、用户媒体或Git历史。

原生M5 Pro GPU成本不是iPhone功耗。正常App默认路径、SCNView提交、多视图和后台生命周期尚未切到H17；下一批范围在[阶段记录](H17-DELIVERY.md)。
