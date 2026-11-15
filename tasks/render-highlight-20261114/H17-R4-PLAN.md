# H17-R4：真实SceneKit动作与同帧提交

R3已经证明近景Compute分离有净收益，但不是播放时序验收。只保留近景，关闭低位重复计时；不重新调旧采样/低维表示。

新增受控顺序：`SCNRenderer.update(atTime:) → 读取最终presentation球态 → 同命令Compute → render(withViewport:commandBuffer:passDescriptor:)`。本机SDK头文件明确后一个render不推进动画。原算法对照仍走原来的render(atTime:...)，实际回调次数和画面对照验证拆开update的成本与时序。

使用父节点SCNAction驱动球体平移/高度；记录首消费帧的update/动画回调、Compute已编码球态与render后presentation/生产uniform的一致性。原showBall强制贴台的漏验在这一轮补齐。相机、粗糙度失效仍按现行轮次重建。

仅在首帧画质、AA/恢复及球态版本通过后计时。AA/AB/DI保留全部6组平衡帧；每臂重新建立同一动作起点和采样时间，避免按不同动画阶段比较。结果仍不是MTKView或SCNView实际present链，也不称完成P3/P4。
