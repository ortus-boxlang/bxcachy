#!/usr/bin/env python3
"""Generates the BxCachy brand SVGs (icon, logo, four wallpapers). Run: python3 assets/build.py && node assets/render.js
Brand gradient #00ff75 to #00dbff is taken from boxlang.svg on boxlang.io."""
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
G1, G2 = "#00ff75", "#00dbff"
defs = f'''<defs>
<linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{G1}"/><stop offset="1" stop-color="{G2}"/></linearGradient>
</defs>'''

def mark(s=100):
    w = s * 0.866
    top = f"M0,{-s} L{w},{-s*0.5} L0,0 L{-w},{-s*0.5} Z"
    left = f"M{-w},{-s*0.5} L0,0 L0,{s} L{-w},{s*0.5} Z"
    right = f"M{w},{-s*0.5} L0,0 L0,{s} L{w},{s*0.5} Z"
    # ">_" sits inside the left face, clear of both edges
    chev = f"M{-s*0.64},{s*0.14} L{-s*0.44},{s*0.26} L{-s*0.64},{s*0.38}"
    under = f"M{-s*0.36},{s*0.40} L{-s*0.16},{s*0.51}"
    sw = s * 0.06
    return f'''<g stroke-linejoin="round"><path d="{top}" fill="url(#g)"/><path d="{left}" fill="url(#g)" opacity="0.55"/><path d="{right}" fill="url(#g)" opacity="0.28"/><path d="{chev}" fill="none" stroke="#06120d" stroke-width="{sw}" stroke-linecap="round"/><path d="{under}" stroke="#06120d" stroke-width="{sw}" stroke-linecap="round"/></g>'''

def outline(s):
    w = s * 0.866
    paths = [f"M0,{-s} L{w},{-s*0.5} L0,0 L{-w},{-s*0.5} Z", f"M{-w},{-s*0.5} L0,0 L0,{s} L{-w},{s*0.5} Z", f"M{w},{-s*0.5} L0,0 L0,{s} L{w},{s*0.5} Z"]
    return '<g fill="none" stroke="url(#g)" stroke-width="2.2" stroke-linejoin="round">' + "".join(f'<path d="{p}"/>' for p in paths) + '</g>'

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{defs}{body}</svg>\n'

FONT = "font-family=\"Inter, 'Noto Sans', 'DejaVu Sans', sans-serif\""
W, H = 2560, 1440
open('icon.svg', 'w').write(svg(256, 256, f'<g transform="translate(128 108)">{mark(100)}</g>'))
open('logo.svg', 'w').write(svg(720, 200, f'<g transform="translate(100 78)">{mark(62)}</g><text x="190" y="118" {FONT} font-size="92" font-weight="700" fill="url(#g)">Bx<tspan fill="#e6fff3">Cachy</tspan></text>'))
open('wallpapers/box.svg', 'w').write(svg(W, H, f'''<defs><radialGradient id="bg" cx="0.5" cy="0.45" r="0.8"><stop offset="0" stop-color="#0f2a20"/><stop offset="1" stop-color="#050b09"/></radialGradient></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<g transform="translate(1280 600) scale(2.6)">{mark(100)}</g>
<text x="1280" y="1040" text-anchor="middle" {FONT} font-size="120" font-weight="700" fill="url(#g)">Bx<tspan fill="#e6fff3">Cachy</tspan></text>
<text x="1280" y="1110" text-anchor="middle" {FONT} font-size="34" fill="#7fb59c" letter-spacing="8">YOUR DEVELOPER MACHINE</text>'''))
lines = ''
for i in range(-20, 21):
    lines += f'<line x1="{1280+i*60}" y1="760" x2="{1280+i*420}" y2="{H}" stroke="url(#g)" stroke-opacity="0.35" stroke-width="2"/>'
for k in range(1, 12):
    y = 760 + (k / 11) ** 2 * (H - 760)
    lines += f'<line x1="0" y1="{y:.1f}" x2="{W}" y2="{y:.1f}" stroke="url(#g)" stroke-opacity="{0.15+0.03*k:.2f}" stroke-width="2"/>'
open('wallpapers/grid.svg', 'w').write(svg(W, H, f'''<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#040807"/><stop offset="0.53" stop-color="#0b2a22"/><stop offset="1" stop-color="#040807"/></linearGradient></defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>{lines}
<g transform="translate(1280 440) scale(1.9)">{mark(100)}</g>
<text x="1280" y="720" text-anchor="middle" {FONT} font-size="64" font-weight="700" fill="#e6fff3" letter-spacing="14">BXCACHY</text>'''))
def blob(i, cx, cy, rx, ry, color, op):
    return f'<radialGradient id="a{i}"><stop offset="0" stop-color="{color}" stop-opacity="{op}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient><ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#a{i})"/>'
open('wallpapers/aurora.svg', 'w').write(svg(W, H, f'''<rect width="{W}" height="{H}" fill="#050b09"/>
{blob(1, 700, 500, 900, 560, G1, 0.55)}{blob(2, 1750, 900, 1000, 580, G2, 0.5)}{blob(3, 1250, 150, 800, 380, "#7c3aed", 0.28)}
<g transform="translate(2300 1220) scale(0.9)">{mark(100)}</g>
<text x="2180" y="1260" text-anchor="end" {FONT} font-size="54" font-weight="700" fill="#e6fff3">BxCachy</text>'''))
open('wallpapers/minimal.svg', 'w').write(svg(W, H, f'''<rect width="{W}" height="{H}" fill="#070d0b"/>
<g transform="translate(1280 600) scale(4.4)">{outline(100)}</g>
<text x="1280" y="1250" text-anchor="middle" {FONT} font-size="40" fill="#5f8a76" letter-spacing="10">BXCACHY</text>'''))
