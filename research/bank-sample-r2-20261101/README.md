# 翻袋小样 r2：排除相对库折返（2026-11-01）

用户指出M2-05“在两个库之间来回两趟的不要，明明一库就可以解决的”。本轮收紧路线形态筛选，不把它解释为所有题都必须证明没有少库解。

原规则只排除主库碰撞中的相对墙A→B→A；本轮把终点袋口归属边界加入检查，补排除A→B→A侧袋口。中袋归属一条长库，角袋归属相交的两条墙；任一终点归属形成相对墙往返即淘汰。几何、物理、主库计数不变，袋口不是新增碰库事件。

保持39题逐字段不变，只替换9题：M2-02/03/04/05、M4-04/06、C2-01/02/04。保留题号作为评阅槽位；题号下内容更新以r2版本标识，原题留在r1与replaced-originals.json。不触及App题库ID/成绩。

候选种子预筛和实际轨迹终验均执行新规则；完整48题另进程重放及独立Python事件审计，旧9题作为回归反例。其它采样与准入规则沿[首轮说明](../bank-sample-20261101/README.md)。允许A→B后转往第三条墙，避免扩大为禁止所有相邻相对库；仍不做少库排他搜索。

```sh
python3 scripts/local_test_lifecycle.py run --task bank-sample-r2-20261101 -- python3 research/bank-sample-r2-20261101/run.py
python3 research/bank-sample-r2-20261101/audit.py
python3 research/bank-sample-r2-20261101/render.py
```

重跑须新输出目录，先准备retained.json与replaced-originals.json；本次输入来自首轮selected.json。失败/旧版证据不覆盖。

重放比较使用有类型事件全部字段的精确数值相等（零容差），避免JSON数字文本不同导致伪失败。初次失败及诊断保留在输出；reverify.py是本次受管work内入口重编的恢复脚本，work已回收后不可直接执行，应走上面的新受管运行。
