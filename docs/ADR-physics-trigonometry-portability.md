# ADR：物理层Float三角函数的跨工具链稳定性

2026-10-28，已实施；源于七练习合并后的冻结路线回归，用户要求修复跨工具链数值差异。

同一初始条件在Xcode26.2与27.1下的Float三角函数路径不同：后者可将标量调用合并为sincos，运行时libm本身也会变化。初速1 ULP差异经碰撞放大，导致原578条冻结参考断言失败。仅禁止内联不足以隔离两类差异。

物理核心改用`PhysicsTrigonometry`：固定Arm optimized-routines多项式、系数、Double分步计算顺序及整数大参数约简，Swift实现随应用版本发布。上游commit和MIT许可见`QiuJi/Resources/ArmOptimizedRoutines-LICENSE.txt`。不引入系统Float sin/cos，也不使用可融合的addingProduct。该实现选择稳定的单精度近似，不声称每个结果正确舍入；独立Double oracle合同为1 Float ULP，包含范围约简消去误差。保留原冻结参考和原容差，不重新生成参考掩盖差异。

变更覆盖物理层所有sin/cos调用；不改atan2/acos/asin、物理系数、计分或历史已存分数。对未来工具链仍须运行独立精度、不变量与冻结路线回归，不将当前两版结果推广为所有CPU/编译器的逐位保证。新增物理函数或优化不得绕过该数值入口。

通过原201,724条中袋证明全量重放后才更新题库清单物理散列；库字节、原杆速和资格判定不变。角袋仍为几何候选。详细原失败、后续验证与平台边界见[专项复验](../tasks/ui-reviews/UR-20261028-training-readability-numerics.md)。
