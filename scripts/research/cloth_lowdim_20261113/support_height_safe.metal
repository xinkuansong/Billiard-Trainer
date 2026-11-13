// Research-only mask predicate. KEEP original shadowPossible, 8/64 choice,
// original above-bed mask predicate and original ball/shadow arithmetic.
// This helper replaces only the unconditional `p.y < 0.8` OR term:
//   (p.y < 0.8 && height_safe_below_mask(p, ball)) || originalInSupport
// originalInSupport is top>=2.2 || dot(offset,offset)<=oldBound*oldBound.
// Domain: current source rig footprint and y between floor and physical bed.
// Outside domain retains old below-bed all-active behavior. No snapping.
bool height_safe_below_mask(float3 p, float4 ball) {
    if (p.y >= 0.8) return false; // helper is for the below-bed OR term only
    // GPU comparisons may flush negative subnormals to zero even without fast math.
    // Preserve the original all-active mask for every negative bit pattern, including -0.
    if ((as_type<uint>(p.y) & 0x80000000u) != 0u) return true;
    if (!(p.y >= 0.0 && abs(p.x) <= 2.5399999618530273 && abs(p.z) <= 1.2699999809265137
          && abs(ball.x) <= 2.5399999618530273 && abs(ball.y) <= 1.2699999809265137)) return true;
    // Upper bounds from actual Float32 near (8x4 per lamp) source operations.
    const float q = 0.2533283829689026;
    const float M = 2.484830617904663;
    const float r = 0.028576001524925232; // nextUp(float(R32 + floor32))
    float centerY = 0.8 + ball.z; // same ball center expression as production
    float gap = 3.0 - centerY - r - q;
    if (!(gap > 0.0)) return true;
    float support = r + (centerY - p.y + r) / gap * (length(ball.xy) + M + q + r);
    float2 delta = p.xz - ball.xy;
    return dot(delta,delta) <= support*support;
}
