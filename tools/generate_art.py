#!/usr/bin/env python3
"""디자인 원본(docs/design/source/Critter.dc.html, ParkBadge.dc.html)의 스케치 룩을 SVG 에셋으로 옮긴다.

임시 에셋 생성기다. 최종 손그림 에셋이 나오면 같은 이름(character-N, badge-<type>, login-hero)으로
Assets.xcassets의 imageset 파일만 교체하면 되고, 이 스크립트는 지워도 된다.

    python3 tools/generate_art.py
"""
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Parknic/Resources/Assets.xcassets"
INK = "#2B2620"
BW = 3.2   # 스케치 룩 외곽선(크기 100 기준)
LW = 3.5   # 눈·입 선
OUTLINE = 0.66  # 캐릭터·배경 그림의 선 굵기 배율(너무 굵으면 유치해 보여서 줄였다)


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def expand(vals):
    if len(vals) == 1:
        return vals * 4
    if len(vals) == 2:
        return [vals[0], vals[1], vals[0], vals[1]]
    if len(vals) == 3:
        return [vals[0], vals[1], vals[2], vals[1]]
    return vals


def parse_radius(css):
    """CSS border-radius('a b c d / e f g h')를 모서리별 (rx, ry) 비율(0~1) 4개로 바꾼다."""
    parts = css.split("/")
    hs = expand([float(v.strip("%")) / 100 for v in parts[0].split()])
    vs = expand([float(v.strip("%")) / 100 for v in parts[1].split()]) if len(parts) > 1 else hs
    return list(zip(hs, vs))


def rrect_path(x, y, w, h, radius):
    (tlx, tly), (trx, try_), (brx, bry), (blx, bly) = [(rx * w, ry * h) for rx, ry in radius]

    def corner(rx, ry, px, py):
        # 반지름 0인 호는 CoreSVG가 거부하므로 직선으로 잇는다.
        return f"A{f(rx)} {f(ry)} 0 0 1 {f(px)} {f(py)}" if rx > 0 and ry > 0 else f"L{f(px)} {f(py)}"

    return (
        f"M{f(x + tlx)} {f(y)}H{f(x + w - trx)}{corner(trx, try_, x + w, y + try_)}"
        f"V{f(y + h - bry)}{corner(brx, bry, x + w - brx, y + h)}"
        f"H{f(x + blx)}{corner(blx, bly, x, y + h - bly)}"
        f"V{f(y + tly)}{corner(tlx, tly, x + tlx, y)}Z"
    )


def polygon_path(x, y, w, h, points, rounding=0):
    pts = [(x + px * w, y + py * h) for px, py in points]
    if not rounding:
        return "M" + "L".join(f"{f(px)} {f(py)}" for px, py in pts) + "Z"
    # 꼭짓점마다 변을 `rounding`만큼 잘라 둥근 곡선으로 잇는다(뾰족한 모서리를 말랑하게).
    n = len(pts)
    d = ""
    for i in range(n):
        px, py = pts[i]
        ax, ay = pts[i - 1]
        bx, by = pts[(i + 1) % n]
        la, lb = math.hypot(ax - px, ay - py), math.hypot(bx - px, by - py)
        ra, rb = min(rounding, la / 2), min(rounding, lb / 2)
        sx, sy = px + (ax - px) / la * ra, py + (ay - py) / la * ra
        ex, ey = px + (bx - px) / lb * rb, py + (by - py) / lb * rb
        d += ("M" if i == 0 else "L") + f"{f(sx)} {f(sy)}Q{f(px)} {f(py)} {f(ex)} {f(ey)}"
    return d + "Z"


def shape(x, y, w, h, fill, radius=None, points=None, rotate=0, stroke=None, sw=0, rounding=0):
    d = polygon_path(x, y, w, h, points, rounding) if points else rrect_path(x, y, w, h, parse_radius(radius or "0%"))
    attrs = f'd="{d}" fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linejoin="round"'
    if rotate:
        attrs += f' transform="rotate({rotate} {f(x + w / 2)} {f(y + h / 2)})"'
    return f"<path {attrs}/>"


def smile(x, y, w, h, color, up=False):
    """border-bottom(또는 border-top)만 있는 반원 선."""
    sweep = 1 if up else 0
    return (f'<path d="M{f(x)} {f(y + h / 2)}A{f(w / 2)} {f(h / 2)} 0 0 {sweep} {f(x + w)} {f(y + h / 2)}" '
            f'fill="none" stroke="{color}" stroke-width="{LW}" stroke-linecap="round"/>')


# ── 캐릭터 ──────────────────────────────────────────────────────────────────
# 100×100 좌표계. 머리는 가로로 넓은 "찹쌀떡" 모양(동글동글), 눈은 크고 낮게, 귀는 짧고 둥글게 둔다.
# 같은 동물끼리도 한눈에 구분되도록 무늬·귀 모양·소품을 캐릭터마다 다르게 둔다.

HEAD = "M50 20C79 20 95 38 95 60C95 82 77 96 50 96C23 96 5 82 5 60C5 38 21 20 50 20Z"
BLUSH = "#FF9C8A"
PINK = "#FF8FA0"


def ell(cx, cy, rx, ry, fill, stroke=None, sw=BW, extra=""):
    d = f"M{f(cx - rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)}Z"
    st = f' stroke="{stroke}" stroke-width="{f(sw * OUTLINE)}" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}"{st}{extra}/>'


def blob(d, fill, stroke=None, sw=BW, extra=""):
    st = f' stroke="{stroke}" stroke-width="{f(sw * OUTLINE)}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}"{st}{extra}/>'


def line(d, color=INK, w=LW):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{f(w * OUTLINE)}" stroke-linecap="round" stroke-linejoin="round"/>'


def mirror(svg):
    """x=50을 기준으로 좌우를 뒤집는다(오른쪽 귀·무늬를 왼쪽과 같은 모양으로)."""
    return f'<g transform="matrix(-1 0 0 1 100 0)">{svg}</g>'


def pair(svg):
    return svg + mirror(svg)


def scallop_path(cx, cy, rx, ry, n, bulge=0.62):
    """구름처럼 몽글몽글한 외곽선(말티즈 털)."""
    pts = [(cx + rx * math.cos(i / n * math.tau - math.pi / 2), cy + ry * math.sin(i / n * math.tau - math.pi / 2))
           for i in range(n)]
    d = f"M{f(pts[0][0])} {f(pts[0][1])}"
    for i in range(n):
        x2, y2 = pts[(i + 1) % n]
        x1, y1 = pts[i]
        r = math.hypot(x2 - x1, y2 - y1) * bulge
        d += f"A{f(r)} {f(r)} 0 0 1 {f(x2)} {f(y2)}"
    return d + "Z"


# 귀(왼쪽 기준. 오른쪽은 mirror로 만든다)
CAT_EAR = "M13 46C9 30 11 15 19 12C29 11 39 19 45 28Z"
CAT_EAR_IN = "M19 37C17 28 19 21 22 19C28 20 34 25 38 30Z"
SHIBA_EAR = "M12 44C8 28 12 14 20 11C31 14 39 22 44 31Z"
CORGI_EAR = "M7 46C0 26 6 6 18 3C31 6 41 18 46 31Z"
CORGI_EAR_IN = "M15 36C11 24 14 14 19 11C26 14 32 21 36 29Z"

PAL = {
    "cheese": dict(c="#F6B25C", ear_in="#FFC9B8", stripe="#DB8F36", muzzle="#FFE7C6"),
    "black": dict(c="#4B4852", ear_in="#D79A98", eye="#D9F07C"),
    "calico": dict(c="#FFF8F0", ear_in="#FAC6BC", orange="#F2A24E", dark="#3F3B45"),
    "tuxedo": dict(c="#3C3B46", ear_in="#D79A98", eye="#F6CC4D", white="#FFFFFF", bow="#E5484D"),
    "shiba": dict(c="#E8A154", ear_in="#FFF1DE", cream="#FFF4E4"),
    "maltese": dict(c="#FFFFFF", ear="#F3EADC", bow="#FF8FA3", shade="#E7DFD3"),
    "beagle": dict(c="#DCA46A", ear="#8E5B33", white="#FFFFFF", patch="#A9703D"),
    "corgi": dict(c="#F3A34C", ear_in="#FFD9C0", white="#FFFFFF"),
}


def eyes(P, mood, ring=None):
    out = []
    for i, x in enumerate((34, 66)):
        if mood == "sleep":
            out.append(line(f"M{f(x - 6)} 64Q{f(x)} 70 {f(x + 6)} 64"))
            continue
        if ring:
            out.append(ell(x, 63, 8, 9.2, ring, INK, 2.4))
            out.append(ell(x, 63.4, 4.2, 7, INK))
        else:
            out.append(ell(x, 63, 5.6, 6.8, INK))
        out.append(ell(x + 2.2, 60.2, 2.2, 2.6, "#fff"))
        out.append(ell(x - 2, 66, 1, 1, "#fff"))
        if mood == "sad":
            rot = 18 if i else -18
            out.append(f'<path d="M{f(x - 6)} 51h12" fill="none" stroke="{INK}" stroke-width="{f(LW * OUTLINE)}" stroke-linecap="round" '
                       f'transform="rotate({rot} {f(x)} 51)"/>')
    return "".join(out)


def blush(mood):
    op = ".3" if mood == "sad" else ".55"
    return f'<g opacity="{op}">{ell(20, 73, 7, 4.2, BLUSH)}{ell(80, 73, 7, 4.2, BLUSH)}</g>'


def cat_face(mood, nose=PINK, mouth=INK):
    out = [blob("M46.4 69.5Q50 68 53.6 69.5Q52.4 73 50 73.4Q47.6 73 46.4 69.5Z", nose)]
    if mood == "sad":
        out.append(line("M43.5 80Q50 74.5 56.5 80", mouth))
    else:
        out.append(line("M50 73.4V75.5", mouth, 2.6))
        out.append(line("M42.6 75Q46.3 80.2 50 75.5Q53.7 80.2 57.4 75", mouth))
    return "".join(out)


def dog_face(mood, tongue=True):
    out = [blob("M44.6 67.6Q50 65 55.4 67.6Q55.6 73.6 50 74.4Q44.4 73.6 44.6 67.6Z", INK),
           ell(48.4, 68, 1.6, 1.1, "#fff", extra=' opacity=".75"')]
    if mood == "sad":
        out.append(line("M43.5 82Q50 76.5 56.5 82"))
    else:
        out.append(line("M50 74.2V77", INK, 2.6))
        out.append(line("M42.6 76.4Q46.3 81.6 50 77Q53.7 81.6 57.4 76.4"))
        if tongue and mood == "happy":
            out.append(blob("M46.2 79.6Q50 78.6 53.8 79.6V83.4Q50 88.4 46.2 83.4Z", "#FF8C8C", INK, 2))
    return "".join(out)


def critter(animal, mood="happy"):
    """100×100 좌표계의 스케치 룩 캐릭터(<g>)."""
    P = PAL[animal]
    out = []

    # ── 귀(머리 뒤) ──
    if animal == "cheese":
        out.append(pair(blob(CAT_EAR, P["c"], INK) + blob(CAT_EAR_IN, P["ear_in"])))
    elif animal in ("black", "tuxedo"):
        out.append(pair(blob(CAT_EAR, P["c"], INK) + blob(CAT_EAR_IN, P["ear_in"])))
    elif animal == "calico":
        out.append(blob(CAT_EAR, P["orange"], INK) + blob(CAT_EAR_IN, P["ear_in"]))
        out.append(mirror(blob(CAT_EAR, P["dark"], INK) + blob(CAT_EAR_IN, P["ear_in"])))
    elif animal == "shiba":
        out.append(pair(blob(SHIBA_EAR, P["c"], INK) + blob("M19 37C17 28 20 21 23 19C28 21 33 26 36 31Z", P["ear_in"])))
    elif animal == "corgi":
        out.append(pair(blob(CORGI_EAR, P["c"], INK) + blob(CORGI_EAR_IN, P["ear_in"])))

    # ── 머리 ──
    if animal == "maltese":
        out.append(blob(scallop_path(50, 58, 44, 37, 14), P["c"], INK))
    else:
        out.append(blob(HEAD, P["c"], INK))

    # ── 무늬 ──
    if animal == "cheese":
        for (x, y, h) in ((44.2, 23, 9), (49, 21.6, 11.5), (53.8, 23, 9)):
            out.append(blob(f"M{f(x)} {f(y + 2)}Q{f(x)} {f(y)} {f(x + 2)} {f(y)}Q{f(x + 4)} {f(y)} {f(x + 4)} {f(y + 2)}V{f(y + h - 2)}Q{f(x + 4)} {f(y + h)} {f(x + 2)} {f(y + h)}Q{f(x)} {f(y + h)} {f(x)} {f(y + h - 2)}Z", P["stripe"]))
        out.append(ell(50, 76, 14, 10, P["muzzle"]))
        # 볼털: 양 볼에 삐죽 나온 털 두 가닥
        out.append(pair(blob("M7.5 61.5Q0 60.5 -3 65Q2 67.5 8 68", P["c"], INK, 2.6) + blob("M7.5 69.5Q0.5 69.5 -2 75Q3 76.5 9 75", P["c"], INK, 2.6)))
    elif animal == "black":
        # 삐죽 머리털(아호)
        out.append(blob("M47 21Q41 10 49.5 8.5Q47.5 13.5 52.5 20Z", P["c"], INK, 2.6))
    elif animal == "calico":
        out.append(blob("M12 47C9 33 22 25 38 26C45 32 40 44 31 50C23 54 14 54 12 47Z", P["orange"]))
        out.append(blob("M63 25C78 24 91 36 90 49C84 51 73 47 67 39C63 33 61 29 63 25Z", P["dark"]))
        out.append(ell(82, 72, 5, 4, P["orange"]))
    elif animal == "tuxedo":
        out.append(blob("M50 54C60 51 71 55 87 66C85 84 69 94 50 94C31 94 15 84 13 66C29 55 40 51 50 54Z", P["white"]))
    elif animal == "shiba":
        out.append(blob("M50 52C63 48 76 54 91 66C90 83 73 94 50 94C27 94 10 83 9 66C24 54 37 48 50 52Z", P["cream"]))
        out.append(ell(34, 50.5, 4, 2.8, P["cream"]) + ell(66, 50.5, 4, 2.8, P["cream"]))
    elif animal == "beagle":
        out.append(blob("M28 28C36 21 64 21 72 28C70 40 60 44 50 44C40 44 30 40 28 28Z", P["patch"]))
        out.append(blob("M50 22C55 22 56 30 55 42L58.5 60C66 62 70 70 68 78C64 86 36 86 32 78C30 70 34 62 41.5 60L45 42C44 30 45 22 50 22Z", P["white"]))
    elif animal == "corgi":
        out.append(blob("M50 22C55 22 56 32 55 46L60 56C72 56 85 64 90 70C86 86 70 95 50 95C30 95 14 86 10 70C15 64 28 56 40 56L45 46C44 32 45 22 50 22Z", P["white"]))

    # ── 말티즈: 몽실몽실 귀와 리본 ──
    if animal == "maltese":
        out.append(pair(blob(scallop_path(13, 64, 11, 19, 8, .7), P["ear"], INK)))
        out.append(blob(scallop_path(48, 17, 13, 9, 7, .75), P["c"], INK))
        out.append(blob("M57 13L69 5.5V20.5Z", P["bow"], INK, 2.4) + blob("M81 13L69 5.5V20.5Z", P["bow"], INK, 2.4)
                   + ell(69, 13, 4.2, 4.4, "#E8607A", INK, 2.2))
    # ── 비글: 길게 처진 귀 ──
    if animal == "beagle":
        out.append(pair(blob("M16 32C7 34 3 52 7 72C10 84 19 86 23 78C26 66 26 48 24 36C22 32 19 31 16 32Z", P["ear"], INK)))

    # ── 얼굴 ──
    ring = P.get("eye")
    out.append(eyes(P, mood, ring))
    out.append(blush(mood))
    if animal in ("cheese", "calico"):
        out.append(cat_face(mood))
    elif animal in ("black", "tuxedo"):
        out.append(cat_face(mood, PINK, "#F4F1EA" if animal == "black" else INK))
    elif animal == "corgi":
        if mood == "happy":
            out.append(blob("M40 71Q50 72.5 60 71Q60 90 50 90Q40 90 40 71Z", "#5A2B2B", INK, 2.4))
            out.append(blob("M44.6 82Q50 79 55.4 82Q54 88.4 50 88.4Q46 88.4 44.6 82Z", "#FF8C8C"))
            out.append(blob("M44 66.6Q50 64 56 66.6Q56 72.2 50 72.8Q44 72.2 44 66.6Z", INK))
        else:
            out.append(dog_face(mood, tongue=False))
    else:
        out.append(dog_face(mood))

    # ── 소품 ──
    if animal == "tuxedo":
        out.append(blob("M50 94L38 88.5V99.5Z", P["bow"], INK, 2.4) + blob("M50 94L62 88.5V99.5Z", P["bow"], INK, 2.4)
                   + ell(50, 94, 3.6, 3.8, "#B93036", INK, 2))
    return '<g transform="rotate(-2 50 50)">' + "".join(out) + "</g>"


def character_svg(animal, mood="happy"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 124 116" width="248" height="232">'
            f'<g transform="translate(12 12)">{critter(animal, mood)}</g></svg>')


# ── 배지 ────────────────────────────────────────────────────────────────────

ICON = {
    "NEIGHBORHOOD": "M5 19c0-8 6-14 14-14 0 8-6 14-14 14z M5 19l7-7",
    "CHILDREN": "M12 3l2.6 5.6 6.1.7-4.5 4.1 1.2 6-5.4-3-5.4 3 1.2-6-4.5-4.1 6.1-.7z",
    "SMALL": "M12 21v-8 M12 13c0-4-3-7-7-7 0 4 3 7 7 7z M12 11c0-4 3-7 7-7 0 4-3 7-7 7z",
    "SPORTS": "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M12 3c-3.5 4-3.5 14 0 18 M12 3c3.5 4 3.5 14 0 18 M3 12h18",
    "WATERFRONT": "M3 8c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 13c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 18c2-2 4-2 6 0s4 2 6 0 4-2 6 0",
    "CULTURE": "M9 18V6l10-2v12 M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0z M19 16a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0z",
    "HISTORY": "M3 8h18 M5 4.5h14 M6 8v12 M18 8v12 M10 20v-6h4v6 M3 20h18",
}
SCALLOP = [(.5 + (.44 if i % 2 else .5) * math.cos(i / 28 * math.tau),
            .5 + (.44 if i % 2 else .5) * math.sin(i / 28 * math.tau)) for i in range(28)]
BADGE = {
    "NEIGHBORHOOD": dict(c="#34B36B", radius="50%"),
    "CHILDREN": dict(c="#FFB627", radius="32%"),
    "SMALL": dict(c="#F58BA6", points=SCALLOP, rounding=4),
    "SPORTS": dict(c="#5C7CF0", points=[(.25, .04), (.75, .04), (1, .5), (.75, .96), (.25, .96), (0, .5)], rounding=14),
    "WATERFRONT": dict(c="#4FB3E8", radius="50% 50% 50% 50% / 58% 58% 42% 42%"),
    "CULTURE": dict(c="#A57FE6", points=[(.3, 0), (.7, 0), (1, .3), (1, .7), (.7, 1), (.3, 1), (0, .7), (0, .3)], rounding=13),
    "HISTORY": dict(c="#C9824F", radius="22% 22% 50% 50% / 16% 16% 58% 58%"),
    "ACHIEVEMENT": dict(c="#FFC533", radius="50%"),  # 아이콘 없이 앱에서 글자를 얹는다
}
LOCKED_FILL = "#F1EBDD"
LOCKED_ICON = "#A79C8C"


def badge_svg(kind, locked=False):
    t = BADGE[kind]
    kw = dict(radius=t.get("radius"), points=t.get("points"), rounding=t.get("rounding", 0))
    body = (
        shape(2.2, 3.4, 100, 100, INK, **kw)
        + shape(0, 0, 100, 100, INK, **kw)
        + shape(4.5, 4.5, 91, 91, LOCKED_FILL if locked else t["c"], **kw)
    )
    if kind in ICON:
        body += (f'<g transform="translate(28 28) scale({44 / 24:.4f})"><path d="{ICON[kind]}" fill="none" '
                 f'stroke="{LOCKED_ICON if locked else INK}" stroke-width="2.2" stroke-linecap="round" '
                 f'stroke-linejoin="round"/></g>')
    # 말랑한 느낌: 왼쪽 위 광택과(획득한 배지는) 오른쪽 위 반짝이
    body += line("M21 33Q25 20 40 15", "#FFFFFF", 5.5).replace('fill="none"', 'fill="none" opacity="%s"' % (".5" if locked else ".7"))
    if not locked:
        body += blob("M90 -3L92.6 4.4L100 7L92.6 9.6L90 17L87.4 9.6L80 7L87.4 4.4Z", "#FFF3B8", INK, 2.2)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 114 114" width="228" height="228">'
            f'<g transform="translate(6 6)"><g transform="rotate(-4 50 50)">{body}</g></g></svg>')


# ── 로그인 일러스트 ──────────────────────────────────────────────────────────

def place(animal, x, y, size, mood="happy"):
    return f'<g transform="translate({f(x)} {f(y)}) scale({size / 100:.4f})">{critter(animal, mood)}</g>'


LOGIN_VIEWBOX = "0 0 393 330"
# 입장 화면의 캐릭터는 앱에서 따로 그려 흔들리게 하므로(Features/Auth/EntryView.swift의 EntryScene),
# 일러스트는 캐릭터 뒤(하늘·해·구름·뒷언덕)와 앞(앞언덕·풀)을 두 장으로 나눠 만든다.
# 캐릭터 배치(캐릭터 100×100 좌표계의 왼쪽 위 x, y와 크기)는 EntryScene.characters와 같아야 한다.
LOGIN_CHARACTERS = [("maltese", 40, 168, 70), ("cheese", 132, 146, 130), ("calico", 292, 178, 62), ("corgi", 350, 236, 34)]


# ── 입장 화면 소품: 캐릭터와 같은 말랑한 모양·굵은 외곽선·볼터치로 그린다 ──

CLOUD = "M12 46C-3 46 -3 25 13 25C13 8 38 4 46 19C54 5 79 9 78 26C94 24 96 46 79 46Z"
SPARKLE = "M0 -9L2.6 -2.6L9 0L2.6 2.6L0 9L-2.6 2.6L-9 0L-2.6 -2.6Z"


def sparkle(x, y, scale=1.0, fill="#FFF3B8"):
    return (f'<g transform="translate({f(x)} {f(y)}) scale({scale})">'
            f'{blob(SPARKLE, fill, INK, 2.2 / scale)}</g>')


def small_face(cx, cy, eye_gap=10, cheek_gap=17, scale=1.0):
    """해·구름 얼굴. 캐릭터와 같은 반짝이는 눈, 볼터치, 작은 미소."""
    k = scale
    e = eye_gap / 2 * k
    c = cheek_gap * k
    return (ell(cx - e, cy, 2.8 * k, 3.4 * k, INK) + ell(cx + e, cy, 2.8 * k, 3.4 * k, INK)
            + ell(cx - e + 1, cy - 1.2 * k, 1.1 * k, 1.3 * k, "#fff") + ell(cx + e + 1, cy - 1.2 * k, 1.1 * k, 1.3 * k, "#fff")
            + f'<g opacity=".55">{ell(cx - c, cy + 7 * k, 4.6 * k, 2.8 * k, BLUSH)}{ell(cx + c, cy + 7 * k, 4.6 * k, 2.8 * k, BLUSH)}</g>'
            + line(f"M{f(cx - 5 * k)} {f(cy + 5.5 * k)}Q{f(cx)} {f(cy + 11 * k)} {f(cx + 5 * k)} {f(cy + 5.5 * k)}", INK, 2.4))


def cloud(x, y, scale, face=False):
    out = f'<g transform="translate({f(x)} {f(y)}) scale({scale})">{blob(CLOUD, "#FFFFFF", INK, 3.2 / scale)}'
    if face:
        out += small_face(45, 33, eye_gap=14, cheek_gap=24, scale=0.9)
    return out + "</g>"


def sun(cx, cy, face=False):
    rays = "".join(
        line(f"M{f(cx + math.cos(a) * 40)} {f(cy + math.sin(a) * 40)}L{f(cx + math.cos(a) * 52)} {f(cy + math.sin(a) * 52)}", INK, 4)
        for a in [i * math.tau / 8 for i in range(8)])
    body = ell(cx, cy, 30, 30, "#FFD77A", INK, 3.2)
    return rays + body + (small_face(cx, cy - 2, eye_gap=22, cheek_gap=20, scale=1.1) if face else "")


def flower(x, y, r, petal, center="#FFD77A"):
    petals = "".join(
        ell(x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.95, r * 0.62, r * 0.62, petal, INK, 1.8)
        for a in [i * math.tau / 5 - math.pi / 2 for i in range(5)])
    return petals + ell(x, y, r * 0.5, r * 0.5, center, INK, 1.8)


def butterfly(x, y, scale=1.0):
    wing = blob("M0 0C-6 -12 -20 -10 -18 0C-17 8 -6 8 0 2Z", "#FFB3C7", INK, 2)
    low = blob("M0 1C-4 6 -12 10 -10 15C-7 19 -1 11 0 4Z", "#FFD6E2", INK, 2)
    return (f'<g transform="translate({f(x)} {f(y)}) scale({scale}) rotate(-12)">'
            f'{wing}{low}<g transform="matrix(-1 0 0 1 0 0)">{wing}{low}</g>'
            f'{line("M0 -4V10", INK, 2.6)}{line("M0 -4Q-3 -9 -6 -9", INK, 1.8)}{line("M0 -4Q3 -9 6 -9", INK, 1.8)}</g>')


def login_back_svg():
    # 깔끔한 풍경: 해(햇살 8방향), 온전한 구름 두 점. 표정·나비·반짝이는 넣지 않는다.
    sky = sun(300, 74) + cloud(24, 78, 1.0) + cloud(168, 24, 0.55)
    back = (f'<path d="M-10 250Q90 200 190 232T410 214V330H-10Z" fill="#CDEBC4"/>'
            f'<path d="M-10 250Q90 200 190 232T410 214" fill="none" stroke="{INK}" stroke-width="2.1" stroke-linecap="round"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{LOGIN_VIEWBOX}" width="393" height="330">{sky}{back}</svg>'


def login_front_svg():
    front = (f'<path d="M-10 290Q120 246 220 270T410 262V330H-10Z" fill="#9FDCB4"/>'
             f'<path d="M-10 290Q120 246 220 270T410 262" fill="none" stroke="{INK}" stroke-width="2.1" stroke-linecap="round"/>'
             f'<g stroke="{INK}" stroke-width="2.1" stroke-linecap="round" fill="none">'
             '<path d="M40 312l5-9l5 9M330 308l5-9l5 9M205 318l4-8l4 8"/></g>'
             + flower(74, 300, 6, "#FFFFFF") + flower(318, 296, 6, "#FFFFFF") + flower(168, 304, 5, "#FFF3B8", "#F5B45E"))
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{LOGIN_VIEWBOX}" width="393" height="330">{front}</svg>'


# ── 체크인 진행 화면 장면 ─────────────────────────────────────────────────────
CHECKIN_VIEWBOX = "0 0 361 170"


def tree(x, base_y, scale=1.0, crown="#8FD9A3"):
    """동글동글한 사탕 나무."""
    k = scale
    trunk = blob(f"M{f(x - 5 * k)} {f(base_y)}V{f(base_y - 26 * k)}Q{f(x)} {f(base_y - 29 * k)} {f(x + 5 * k)} {f(base_y - 26 * k)}V{f(base_y)}Z", "#C9824F", INK, 2.6)
    top = ell(x, base_y - 46 * k, 22 * k, 24 * k, crown, INK, 3.0)
    shine = line(f"M{f(x - 13 * k)} {f(base_y - 52 * k)}Q{f(x - 11 * k)} {f(base_y - 62 * k)} {f(x - 3 * k)} {f(base_y - 65 * k)}", "#FFFFFF", 3.4)
    shine = shine.replace('fill="none"', 'fill="none" opacity=".7"')
    return trunk + top + shine


def checkin_scene_svg():
    ground = (f'<path d="M-10 128Q70 104 150 118T290 108T380 118V180H-10Z" fill="#CDEBC4"/>'
              f'<path d="M-10 128Q70 104 150 118T290 108T380 118" fill="none" stroke="{INK}" stroke-width="2.1" stroke-linecap="round"/>'
              f'<path d="M-10 152Q90 130 180 146T380 140V180H-10Z" fill="#9FDCB4"/>'
              f'<path d="M-10 152Q90 130 180 146T380 140" fill="none" stroke="{INK}" stroke-width="2.1" stroke-linecap="round"/>')
    scenery = cloud(20, 12, 0.5) + cloud(246, 24, 0.55)
    trees = tree(34, 128, 1.0) + tree(326, 124, 0.85, crown="#A8E2B5")
    flowers = flower(86, 152, 5.5, "#FFFFFF") + flower(268, 154, 5.5, "#FFFFFF") + flower(160, 162, 4.5, "#FFF3B8", "#F5B45E")
    tufts = (f'<g stroke="{INK}" stroke-width="2.1" stroke-linecap="round" fill="none">'
             '<path d="M120 160l4-8l4 8M226 162l4-8l4 8"/></g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{CHECKIN_VIEWBOX}" width="361" height="170">'
            f'{scenery}{ground}{trees}{flowers}{tufts}</svg>')


# ── 카탈로그 쓰기 ────────────────────────────────────────────────────────────

def write_imageset(name, svg):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.svg").write_text(svg, encoding="utf-8")
    contents = {
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main():
    animals = ["cheese", "black", "calico", "tuxedo", "shiba", "maltese", "beagle", "corgi"]  # 서버 캐릭터 ID 1~8 순서
    for i, animal in enumerate(animals, start=1):
        write_imageset(f"character-{i}", character_svg(animal))
    write_imageset("character-default", character_svg("cheese"))
    write_imageset("character-sad", character_svg("cheese", "sad"))
    for kind in BADGE:
        write_imageset(f"badge-{kind.lower()}", badge_svg(kind))
        write_imageset(f"badge-{kind.lower()}-locked", badge_svg(kind, locked=True))
    write_imageset("checkin-scene", checkin_scene_svg())
    write_imageset("login-back", login_back_svg())
    write_imageset("login-front", login_front_svg())
    old = CATALOG / "login-hero.imageset"
    if old.exists():  # 예전 한 장짜리 일러스트(캐릭터 포함)는 쓰지 않는다.
        for child in old.iterdir():
            child.unlink()
        old.rmdir()
    print("생성 완료:", len(animals) + 2 + len(BADGE) * 2 + 3, "개")


if __name__ == "__main__":
    main()
