# ImageGen 最终提示词

生成模式：Codex 内置 ImageGen。各组把项目截图或当前封面作为风格和产品语境参考，不把它们当编辑目标。

- `tmp/designer-screenshots/01-training-home.png`
- `tmp/designer-screenshots/05-drill-library.png`
- `tmp/designer-screenshots/08-angle-home-all.png`

## A｜真实台面 · 编辑式光影

```text
Use case: photorealistic-natural
Asset type: onboarding visual direction board for an iOS billiards training app
Primary request: create one polished landscape triptych containing three equal vertical illustration panels that tell a clear progression: understand the shot, practice with structure, see progress.
Input images: Image 1, Image 2, and Image 3 are style and product-context references only. Borrow their restrained iOS product mood, deep billiard green, near-white background, dark rail, real felt and ball materials. Do not copy any UI, text, logos, tab bars, or screen chrome.
Panel 1 subject: an elegant close oblique view of a cue ball and one target ball on real green felt, with one restrained thin white aim line and one tiny warm-gold contact-point glow, visually communicating "understand the path".
Panel 2 subject: a disciplined practice setup on the same table, cue aligned and a short sequence of three ball positions or subtle position markers arranged cleanly, visually communicating "structured practice"; keep it plausible and uncluttered.
Panel 3 subject: the same cue ball beside a restrained trail of small luminous green progress dots and a subtle rising path motif integrated into the felt, visually communicating "progress becomes visible"; it must still feel like a billiards scene, not a finance chart.
Style/medium: premium photoreal editorial product photography, authentic felt fibers, glossy phenolic balls, softly worn wood rail, iOS-quality polish, no people.
Composition/framing: three equal portrait panels inside one 3:2 landscape canvas; consistent camera family and lighting; generous quiet negative space in the lower quarter of every panel for future SwiftUI copy; keep important objects above the center.
Lighting/mood: soft controlled billiard-hall light, calm, focused, aspirational, not dramatic or moody.
Color palette: deep billiard green, near-white, charcoal, a very small warm-gold accent; restrained saturation.
Constraints: no text, no letters, no numbers, no logos, no watermark, no phone frames, no fake UI, no busy background, no excessive glow, no impossible ball geometry, no extra cue sticks. The three panels must be visually coherent as one series and clearly distinct in meaning.
```

## D｜单一焦点 · 真实训练过程

### D1｜看懂碰撞点

```text
Use case: photorealistic-natural
Asset type: first onboarding hero image for a professional iOS billiards training app
Primary request: create a single, immediately readable image about understanding one shot before striking. The visual focus must be the exact contact moment between the cue ball and target ball, not the whole table and not a collection of features.
Input images: Image 1 is a material and lighting reference for the app's current photographic cover style. Image 2 is a product-context reference for the app's real trajectory language. Do not copy UI, text, buttons, logos or screen chrome.
Scene/backdrop: a real Chinese pool table with deep green felt and dark wood rail; one corner pocket is visible in the upper-right background.
Subject: one cream cue ball with six restrained red dots in the lower-left foreground, one amber target ball near the center, and the corner pocket upper-right. A single thin white aiming line runs from the cue ball toward the target ball; a tiny warm-gold contact point and one clean translucent ghost-ball ring sit exactly at the collision focus; one thin amber line continues from the target ball to the pocket. No other balls.
Style/medium: premium photoreal editorial product photography with precise minimal instructional overlays, authentic felt fiber, glossy phenolic balls, restrained iOS polish.
Composition/framing: 3:2 landscape onboarding hero; collision point occupies the visual center and is the brightest sharpest point; cue ball large but secondary; pocket visible but subdued; shallow depth falloff toward edges; no empty lower text area needed because copy sits below the hero in SwiftUI.
Lighting/mood: clean focused overhead pool-hall light, calm, professional, confident; no cinematic darkness.
Color palette: deep billiard green, cream, charcoal, amber and one tiny gold highlight.
Constraints: exactly two balls, one cue, one pocket, one main aim line, one target-to-pocket line, one contact point, one ghost-ball ring. No charts, no progress dots, no repeated tables, no phone, no person, no text, no letters, no numbers, no logo, no watermark, no neon glow, no decorative objects, no impossible curved trajectory. The contact point must dominate the first glance.
```

### D2｜正在按球形训练

```text
Use case: photorealistic-natural
Asset type: second onboarding hero image for a professional iOS billiards training app
Primary request: create a single, immediately readable image about following a structured billiards practice instead of casually hitting balls. The visual focus must be the player's hand placing the final ball into one precise training formation.
Input images: Image 1 is a material and lighting reference for the app's current photographic cover style. Image 2 is product-context reference for the app's planned daily training concept. Do not copy UI, text, cards, logos or screen chrome.
Scene/backdrop: a real Chinese pool table under clean billiard-hall light, deep green felt and dark wood rail.
Subject: a player's hand enters naturally from the upper edge and places one amber target ball onto a small precise position marker, completing a straight, disciplined training formation of one cream six-red-dot cue ball and four colored object balls. A single cue lies aligned behind the cue ball. Three very subtle warm-gold station dots on the felt show repeat positions. The scene should clearly look prepared for deliberate practice, not a game in progress.
Style/medium: premium photoreal editorial sports photography, authentic hand anatomy, felt fibers, glossy phenolic balls, restrained iOS product polish.
Composition/framing: 3:2 landscape onboarding hero; the hand, amber ball and its exact marker form one central focal cluster occupying the middle third; the aligned cue and formation create one strong direction through the frame; crop out the player's face and body; background falls softly out of focus.
Lighting/mood: bright focused overhead table light, purposeful, calm, encouraging, not dramatic.
Color palette: billiard green, cream cue ball, restrained object-ball colors, dark wood, tiny warm-gold markers.
Constraints: one natural hand only, one cue only, one cue ball, exactly five object balls, one coherent formation. No phone, no charts, no repeated tables, no floating cards, no text, no letters, no numbers, no logos, no watermark, no neon, no trophy, no confetti, no decorative props. The first glance must read as "setting up a precise practice drill".
```

### D3｜薄弱点直达下一项训练

```text
Use case: product-mockup
Asset type: third onboarding hero image for a professional iOS billiards training app
Primary request: create a single, immediately readable image about reviewing practice and knowing exactly what to train next. The visual focus must be one amber weak-point marker leading directly to one next-practice card, not a generic dashboard.
Input images: Image 1 is product-context reference for the app's statistics language. Image 2 is product-context reference for the app's daily training card language. Image 3 is material reference for the billiards photography. Do not copy text, logos, tab bars or full screen chrome.
Scene/backdrop: a clean real billiards table edge with deep green felt and dark wood rail, softly out of focus.
Subject: one modern smartphone resting upright at a slight angle on the rail, filling most of the frame. Its screen contains a minimal abstract app interface: at the top, one large precision target made of three thin green rings with a small cluster of green shot dots and exactly one clearly separated amber dot indicating a weak area; directly below, one prominent white rounded next-practice card containing a small green table thumbnail with a simple straight-shot formation and a green play circle. No readable text or numbers. A cream six-red-dot cue ball sits beside the phone as a small real-world anchor.
Style/medium: premium realistic iOS product photography and product mockup, authentic materials, crisp device, restrained interface, no sci-fi.
Composition/framing: 3:2 landscape onboarding hero; the amber weak-point dot and the next-practice card align on one vertical visual axis at the center of the phone; everything else is quiet and secondary; shallow depth of field outside the phone.
Lighting/mood: bright controlled table light, calm, useful, motivating.
Color palette: off-white screen, billiard green, charcoal, cream cue ball, one amber highlight only.
Constraints: one phone, one cue ball, one target visualization, one amber weak point, one next-practice card. No charts, no bar graphs, no multiple cards, no trophy, no star, no confetti, no floating decorative elements, no person, no text, no letters, no numbers, no logo, no watermark, no neon, no extra balls. The first glance must read as "the app found one weakness and gives the next drill".
```

## B｜轻量 3D · 训练系统

```text
Use case: stylized-concept
Asset type: onboarding visual direction board for an iOS billiards training app
Primary request: create one polished landscape triptych containing three equal vertical panels that explain the progression: understand, practice, improve.
Input images: Image 1, Image 2, and Image 3 are style and product-context references only. Borrow the restrained iOS card language, billiard green, off-white canvas, charcoal details, rounded geometry and minimal gold accent. Do not copy any UI, text, logos, tab bars, or screen chrome.
Panel 1 subject: a compact isometric miniature billiards table fragment with cue ball, target ball, a thin route line, ghost-ball/contact marker, and one gold contact dot; communicate understanding the shot.
Panel 2 subject: a compact isometric practice system with three small connected training-table tiles or stations, a cue and balls progressing through them; communicate a structured daily routine.
Panel 3 subject: a compact isometric progress scene combining a cue ball, a simple seven-dot weekly rhythm and one restrained rising accuracy curve built from small green markers; communicate visible improvement without looking like finance.
Style/medium: premium soft 3D product illustration, tactile felt, matte white cards, dark wood/charcoal rails, subtle ambient occlusion, iOS product onboarding quality, friendly but not childish.
Composition/framing: three equal portrait panels within one 3:2 landscape canvas; each object group centered in the upper two-thirds; generous clean negative space in the lower quarter for future SwiftUI copy; consistent scale and perspective.
Lighting/mood: bright diffuse studio light, calm, focused, encouraging.
Color palette: near-white #F2F2F7-like background, billiard green, cream cue ball, charcoal, tiny warm-gold accent; low saturation outside green.
Constraints: no text, no letters, no numbers, no logos, no watermark, no phone frames, no fake UI, no people, no neon, no glassmorphism, no confetti, no excessive floating decorations, no impossible ball geometry. The three panels must read as one coherent series.
```

## C｜几何球路 · 数据编辑式

```text
Use case: stylized-concept
Asset type: onboarding visual direction board for an iOS billiards training app
Primary request: create one sophisticated landscape triptych of three equal vertical editorial illustrations for the progression: understand the shot, build a practice system, review improvement.
Input images: Image 1, Image 2, and Image 3 are style and product-context references only. Use their restrained green, off-white, charcoal, rounded-card visual language and billiards subject matter. Do not copy any UI, text, logos, tab bars, or screen chrome.
Panel 1 subject: a large cream cue ball and one amber target ball on a simplified deep-green felt plane, with precise thin trajectory lines, a ghost-ball ring and a tiny gold contact point; visually communicate billiards geometry and prediction.
Panel 2 subject: three neat layered training cards represented as cropped felt rectangles, each carrying a different minimal ball formation and short path, arranged as a clear sequence; visually communicate a systematic practice plan.
Panel 3 subject: a cream cue ball next to a restrained seven-column practice rhythm and a smooth accuracy trend made from dots and one fine line, all integrated into the billiards visual language; visually communicate review and steady improvement.
Style/medium: premium editorial graphic illustration, crisp vector-like geometry mixed with very subtle felt grain and soft paper texture, modern Chinese iOS product design, sophisticated and calm, not cartoonish.
Composition/framing: three equal portrait panels within one 3:2 landscape canvas; strong single focal object per panel; quiet negative space in the lower quarter for future SwiftUI text; generous margins; consistent visual scale.
Lighting/mood: clean diffuse light, focused and confident.
Color palette: deep billiard green, off-white, charcoal, one amber target-ball accent and tiny warm-gold detail; avoid extra colors.
Constraints: no text, no letters, no numbers, no logos, no watermark, no phone frames, no fake UI controls, no people, no generic dashboard icons, no neon, no decorative blobs, no gradients that overpower the illustration, no impossible ball geometry. Three panels must form one coherent family while clearly communicating three different benefits.
```
