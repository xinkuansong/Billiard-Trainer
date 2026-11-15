# H14-R3：减少双面光栅化

2026-11-14，R2构建期间从代码和原始USDZ发现新的结构性成本。事前计划，不将原始资源状态冒充已验证的生产/GPU收益。

只读作业`d2f8b17a13d74432937e2abf56dc44de`导入当前ModelTrial20261010_TaiQiuZhuo.usdz：Plane_001共有131287个顶点，目标TaiNi/BlackWood/Wood/MG_Gold元素均为双面、透明度1、深度读写打开；Plane_001桌腿65824个三角形，Plane_007桌腿16143个三角形，共81967。TaiNi/BlackWood primitiveType=polygon，不误称其primitiveCount为三角形数。独立库存和脚本已封存，临时编译缓存已回收。

生产TableAppearance/TableMaterialRecipe通过SCNMaterial.copy保存渲染状态；当前生产只发现球工厂显式关双面，目标台面材质未显式更改。原生研究先记录并断言实际目标材质isDoubleSided=true，再独立对wood/legs/cloth设置false和cullMode=back，其他程序/材质/几何保持原样，恢复后逐像素零差。若目标已非双面，拒绝实验资格而不算收益。

此方向不改变高光/遮挡公式，目标是减少背面几何的光栅化及潜在片元工作。Apple GPU可能已经有效剔除不可见片元，不能从双面标志直接推断收益。模型可能有薄片/反向面，关闭双面会改变外观，先执行H14既定三机位画质门槛与6组AA/AB性能门槛；任一可见破损均淘汰对应材质，不以性能好为理由接入。

只有通过初筛的材质才继续多机位、五桌色/六台呢色、两尺寸及动态球态的扩展画质。初筛仍为当前原生场景GPU命令跨度，不是整页/手机温升。原生资源预算和逐帧提交沿H14-PLAN；R1/R2候选不混入。
