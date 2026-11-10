//! Drawing: the welcome splash, the pages with a step sidebar, and the review. Everything is drawn straight into the
//! terminal buffer with true colour, so gradients and shimmer are possible; clicks are recorded as hit regions.
use crate::app::{rows, Action, App, Hit, Row, Screen};
use crate::art;
use crate::model::Question;
use crate::theme::*;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::Frame;

fn fg(c: Color) -> Style {
    Style::new().fg(c)
}

/// Writes text one cell per char, clipped to `clip`.
fn put(buf: &mut Buffer, clip: Rect, x: i32, y: i32, s: &str, style: Style) -> i32 {
    let mut cx = x;
    for ch in s.chars() {
        if cx >= clip.x as i32 && cx < (clip.x + clip.width) as i32 && y >= clip.y as i32 && y < (clip.y + clip.height) as i32 {
            buf[(cx as u16, y as u16)].set_char(ch).set_style(style);
        }
        cx += 1;
    }
    cx
}

/// Text with the brand gradient across its width; `phase` moves a soft highlight along it.
fn gradient_text(buf: &mut Buffer, clip: Rect, x: i32, y: i32, s: &str, bold: bool, phase: f32, bg: Color) {
    let n = s.chars().count() as f32;
    for (i, ch) in s.chars().enumerate() {
        let mut st = Style::new().fg(shimmer(i as f32, n, phase)).bg(bg);
        if bold {
            st = st.add_modifier(Modifier::BOLD);
        }
        put(buf, clip, x + i as i32, y, &ch.to_string(), st);
    }
}

fn fill(buf: &mut Buffer, r: Rect, bg: Color) {
    for y in r.y..r.y + r.height {
        for x in r.x..r.x + r.width {
            buf[(x, y)].set_char(' ').set_bg(bg).set_fg(TEXT);
        }
    }
}

/// A rounded panel; `accent` draws the border in the brand gradient.
fn panel(buf: &mut Buffer, r: Rect, title: &str, accent: bool, phase: f32) {
    fill(buf, r, MANTLE);
    let (x0, y0, x1, y1) = (r.x as i32, r.y as i32, (r.x + r.width - 1) as i32, (r.y + r.height - 1) as i32);
    let clip = buf.area;
    let color = |i: i32| if accent { shimmer(i as f32, r.width as f32, phase) } else { SURFACE1 };
    for x in x0 + 1..x1 {
        put(buf, clip, x, y0, "─", fg(color(x - x0)).bg(MANTLE));
        put(buf, clip, x, y1, "─", fg(color(x - x0)).bg(MANTLE));
    }
    for y in y0 + 1..y1 {
        put(buf, clip, x0, y, "│", fg(color(0)).bg(MANTLE));
        put(buf, clip, x1, y, "│", fg(color(x1 - x0)).bg(MANTLE));
    }
    put(buf, clip, x0, y0, "╭", fg(color(0)).bg(MANTLE));
    put(buf, clip, x1, y0, "╮", fg(color(x1 - x0)).bg(MANTLE));
    put(buf, clip, x0, y1, "╰", fg(color(0)).bg(MANTLE));
    put(buf, clip, x1, y1, "╯", fg(color(x1 - x0)).bg(MANTLE));
    if !title.is_empty() {
        let t = format!(" {} ", title);
        put(buf, clip, x0 + 2, y0, &t, fg(TEXT).bg(MANTLE).add_modifier(Modifier::BOLD));
        gradient_text(buf, clip, x0 + 3, y0, title, true, phase, MANTLE);
    }
}

fn wrap(text: &str, width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    let mut cur = String::new();
    for word in text.split_whitespace() {
        if !cur.is_empty() && cur.chars().count() + 1 + word.chars().count() > width {
            lines.push(std::mem::take(&mut cur));
        }
        if !cur.is_empty() {
            cur.push(' ');
        }
        cur.push_str(word);
    }
    if !cur.is_empty() {
        lines.push(cur);
    }
    lines
}

fn art_block(buf: &mut Buffer, clip: Rect, x: i32, y: i32, lines: &[&str], phase: f32) {
    let w = lines.iter().map(|l| l.chars().count()).max().unwrap_or(1) as f32;
    let h = lines.len() as f32;
    for (dy, line) in lines.iter().enumerate() {
        for (dx, ch) in line.chars().enumerate() {
            if ch == ' ' {
                continue;
            }
            let t = (dx as f32 + dy as f32 * 0.6) / (w + h * 0.6);
            let c = shimmer(t * w, w, phase);
            put(buf, clip, x + dx as i32, y + dy as i32, &ch.to_string(), fg(c).bg(BASE));
        }
    }
}

pub fn draw(f: &mut Frame, app: &mut App) {
    let area = f.area();
    app.hits.clear();
    let tick = app.tick;
    let buf = f.buffer_mut();
    fill(buf, area, BASE);
    if area.width < 76 || area.height < 24 {
        let msg = "Make the window a little bigger (76 x 24)";
        put(buf, area, (area.width as i32 - msg.len() as i32) / 2, area.height as i32 / 2, msg, fg(YELLOW).bg(BASE));
        return;
    }
    let phase = ((tick % 90) as f32) / 90.0 * 1.4 - 0.2;
    if app.screen != app.last_screen {
        app.last_screen = app.screen;
        app.changed_at = tick;
    }
    match app.screen {
        Screen::Welcome => welcome(buf, area, app, phase),
        _ => pages(buf, area, app, phase),
    }
    // fade the new screen in from the background colour
    let age = tick.saturating_sub(app.changed_at) as f32 / 7.0;
    if age < 1.0 {
        let k = age * age * (3.0 - 2.0 * age);
        for y in area.y..area.y + area.height {
            for x in area.x..area.x + area.width {
                let c = &mut buf[(x, y)];
                c.set_fg(lerp(BASE, c.fg, k));
                c.set_bg(lerp(BASE, c.bg, k));
            }
        }
    }
}

/// Twinkling dots behind the welcome art. Positions are fixed (a small deterministic generator), brightness moves.
fn starfield(buf: &mut Buffer, area: Rect, avoid: Rect, tick: u64) {
    let mut seed: u32 = 0x9e37_79b9;
    for i in 0..46 {
        seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
        let x = (seed >> 8) % area.width as u32;
        seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
        let y = (seed >> 8) % area.height as u32;
        let (x, y) = (x as u16, y as u16);
        if x >= avoid.x && x < avoid.x + avoid.width && y >= avoid.y && y < avoid.y + avoid.height {
            continue;
        }
        let tw = (((tick as f32) / 14.0 + i as f32 * 1.7).sin() * 0.5 + 0.5) * 0.85;
        let glyph = if i % 7 == 0 { "+" } else { "·" };
        put(buf, area, x as i32, y as i32, glyph, fg(lerp(BASE, if i % 3 == 0 { CYAN } else { SUB }, tw * 0.8)).bg(BASE));
    }
}

fn welcome(buf: &mut Buffer, area: Rect, app: &App, phase: f32) {
    let icon_w = art::ICON.iter().map(|l| l.chars().count()).max().unwrap_or(0) as i32;
    let mark_w = art::WORDMARK.iter().map(|l| l.chars().count()).max().unwrap_or(0) as i32;
    let total_h = art::ICON.len() as i32 + 1 + art::WORDMARK.len() as i32 + 4;
    let top = ((area.height as i32 - total_h) / 2).max(1);
    let cx = area.width as i32 / 2;
    let avoid = Rect { x: (cx - mark_w / 2 - 1).max(0) as u16, y: top.max(0) as u16, width: (mark_w + 2) as u16, height: (total_h + 1) as u16 };
    starfield(buf, area, avoid, app.tick);
    art_block(buf, area, cx - icon_w / 2, top, art::ICON, phase);
    let y = top + art::ICON.len() as i32 + 1;
    if mark_w < area.width as i32 - 2 {
        art_block(buf, area, cx - mark_w / 2, y, art::WORDMARK, phase);
    } else {
        gradient_text(buf, area, cx - 3, y, "BxCachy", true, phase, BASE);
    }
    let y = y + art::WORDMARK.len() as i32 + 1;
    let tag = if app.spec.tagline.is_empty() { "Your developer machine, set up in minutes." } else { &app.spec.tagline };
    put(buf, area, cx - tag.chars().count() as i32 / 2, y, tag, fg(SUB).bg(BASE));
    let prompt = "press  enter  to begin";
    let pulse = ((app.tick as f32 / 8.0).sin() * 0.5 + 0.5) * 0.7 + 0.3;
    put(buf, area, cx - prompt.len() as i32 / 2, y + 2, prompt, fg(lerp(OVERLAY, GREEN, pulse)).bg(BASE));
    if !app.spec.version.is_empty() {
        let v = format!("v{}", app.spec.version);
        put(buf, area, cx - v.len() as i32 / 2, area.height as i32 - 2, &v, fg(OVERLAY).bg(BASE));
    }
}

fn pages(buf: &mut Buffer, area: Rect, app: &mut App, phase: f32) {
    let w = area.width as i32;
    let n = app.spec.pages.len();
    let step = match app.screen {
        Screen::Page(i) => i + 1,
        _ => n + 1,
    };
    // header
    gradient_text(buf, area, 3, 1, "◆ BxCachy", true, phase, BASE);
    put(buf, area, 13, 1, "setup", fg(SUB).bg(BASE));
    let label = format!("step {} of {}", step.min(n + 1), n + 1);
    let bar_w = 24;
    let bar_x = w - bar_w - 3;
    put(buf, area, bar_x - label.len() as i32 - 2, 1, &label, fg(SUB).bg(BASE));
    for i in 0..bar_w {
        let filled = (i as f32 + 1.0) / bar_w as f32 <= step as f32 / (n + 1) as f32;
        let c = if filled { gradient(i as f32 / bar_w as f32) } else { SURFACE0 };
        put(buf, area, bar_x + i, 1, if filled { "━" } else { "─" }, fg(c).bg(BASE));
    }
    for x in 2..w - 2 {
        put(buf, area, x, 2, "─", fg(lerp(SURFACE1, shimmer(x as f32, w as f32, phase), 0.25)).bg(BASE));
    }
    // footer
    let hints: [(&str, &str); 6] = [("↑↓", "move"), ("space", "select"), ("enter", "next"), ("tab", "next page"), ("esc", "back"), ("ctrl-c", "cancel")];
    let mut x = 3;
    for (k, d) in hints {
        x = put(buf, area, x, area.height as i32 - 1, k, fg(CYAN).bg(BASE)) + 1;
        x = put(buf, area, x, area.height as i32 - 1, d, fg(OVERLAY).bg(BASE)) + 3;
    }
    // body
    let body = Rect { x: 2, y: 3, width: area.width - 4, height: area.height - 4 };
    let side_w: u16 = if area.width >= 92 { 28 } else { 0 };
    if side_w > 0 {
        sidebar(buf, Rect { x: body.x, y: body.y, width: side_w, height: body.height }, app, phase);
    }
    let main = Rect { x: body.x + side_w + if side_w > 0 { 1 } else { 0 }, y: body.y, width: body.width - side_w - if side_w > 0 { 1 } else { 0 }, height: body.height };
    match app.screen {
        Screen::Review => review(buf, main, app, phase),
        _ => page(buf, main, app, phase),
    }
}

fn sidebar(buf: &mut Buffer, r: Rect, app: &mut App, phase: f32) {
    panel(buf, r, "Steps", false, phase);
    let current = match app.screen {
        Screen::Page(i) => Some(i),
        _ => None,
    };
    let n = app.spec.pages.len();
    for i in 0..=n {
        let y = r.y as i32 + 2 + i as i32;
        if y >= (r.y + r.height) as i32 - 1 {
            break;
        }
        let is_review = i == n;
        let title = if is_review { "Review".to_string() } else { app.spec.pages[i].title.clone() };
        let here = if is_review { app.screen == Screen::Review } else { current == Some(i) };
        let reached = i <= app.furthest;
        let done = i < app.furthest && !here;
        let row = Rect { x: r.x + 1, y: y as u16, width: r.width - 2, height: 1 };
        if here {
            fill(buf, row, SURFACE0);
            put(buf, r, r.x as i32 + 1, y, "▌", fg(GREEN).bg(SURFACE0));
        }
        let bg = if here { SURFACE0 } else { MANTLE };
        let (mark, color) = if done { ("●", GREEN) } else if here { ("●", CYAN) } else if reached { ("●", SUB) } else { ("○", OVERLAY) };
        put(buf, r, r.x as i32 + 3, y, mark, fg(color).bg(bg));
        if here {
            gradient_text(buf, r, r.x as i32 + 6, y, &title, true, phase, bg);
        } else {
            put(buf, r, r.x as i32 + 6, y, &title, fg(if reached { TEXT } else { OVERLAY }).bg(bg));
        }
        if reached {
            app.hits.push(Hit { rect: row, action: if is_review { Action::GotoReview } else { Action::GotoPage(i) } });
        }
    }
}

fn page(buf: &mut Buffer, r: Rect, app: &mut App, phase: f32) {
    let Some(pg) = app.page().cloned() else { return };
    let rws = rows(&pg);
    panel(buf, r, &pg.title, true, phase);
    let inner = Rect { x: r.x + 3, y: r.y + 1, width: r.width - 6, height: r.height - 2 };
    let mut y = inner.y as i32 + 1;
    if !pg.intro.is_empty() {
        for line in wrap(&pg.intro, inner.width as usize) {
            put(buf, inner, inner.x as i32, y, &line, fg(SUB).bg(MANTLE));
            y += 1;
        }
        y += 1;
    }
    let detail_h = 4i32;
    let list_top = y;
    let list_bottom = (inner.y + inner.height) as i32 - detail_h;
    // heights
    let height_of = |row: &Row| -> i32 {
        match row {
            Row::Heading(q) => 1 + if pg.questions[*q].help().is_empty() { 0 } else { 1 },
            Row::Info(q) => 1 + wrap(pg.questions[*q].help(), inner.width as usize).len() as i32,
            _ => 1,
        }
    };
    let mut tops = Vec::new();
    let mut t = 0;
    for row in &rws {
        tops.push(t);
        t += height_of(row);
    }
    let avail = (list_bottom - list_top).max(1);
    let f_top = tops.get(app.focus).copied().unwrap_or(0);
    let f_h = rws.get(app.focus).map(height_of).unwrap_or(1);
    let scroll = if f_top + f_h > avail { f_top + f_h - avail } else { 0 };
    let list_clip = Rect { x: inner.x, y: list_top as u16, width: inner.width, height: avail as u16 };
    let w = inner.width as i32;
    for (idx, row) in rws.iter().enumerate() {
        let ry = list_top + tops[idx] - scroll;
        if ry < list_top || ry + height_of(row) > list_bottom + 0 {
            continue;
        }
        let focused = idx == app.focus;
        match row {
            Row::Heading(q) => {
                let qn = &pg.questions[*q];
                put(buf, list_clip, inner.x as i32, ry, qn.label(), fg(TEXT).bg(MANTLE).add_modifier(Modifier::BOLD));
                if !qn.help().is_empty() {
                    put(buf, list_clip, inner.x as i32, ry + 1, qn.help(), fg(OVERLAY).bg(MANTLE));
                }
            }
            Row::Group(g) => {
                put(buf, list_clip, inner.x as i32 + 2, ry, &g.to_uppercase(), fg(OVERLAY).bg(MANTLE).add_modifier(Modifier::BOLD));
            }
            Row::Info(q) => {
                let qn = &pg.questions[*q];
                put(buf, list_clip, inner.x as i32, ry, qn.label(), fg(TEXT).bg(MANTLE).add_modifier(Modifier::BOLD));
                for (k, line) in wrap(qn.help(), inner.width as usize).iter().enumerate() {
                    put(buf, list_clip, inner.x as i32, ry + 1 + k as i32, line, fg(SUB).bg(MANTLE));
                }
            }
            Row::Space => {}
            Row::Opt(q, i) => {
                let (opt, selected, multi) = match &pg.questions[*q] {
                    Question::Choice { id, options, .. } => (&options[*i], app.answer_str(id) == options[*i].value, false),
                    Question::Multi { id, options, .. } => (&options[*i], app.answer_list(id).contains(&options[*i].value), true),
                    _ => continue,
                };
                let row_rect = Rect { x: inner.x, y: ry as u16, width: inner.width, height: 1 };
                let bg = if focused { SURFACE0 } else { MANTLE };
                if focused {
                    fill(buf, row_rect, SURFACE0);
                    put(buf, list_clip, inner.x as i32, ry, "▌", fg(gradient(0.5)).bg(SURFACE0));
                }
                let mark = match (multi, selected) {
                    (false, true) => "●",
                    (false, false) => "○",
                    (true, true) => "◆",
                    (true, false) => "◇",
                };
                put(buf, list_clip, inner.x as i32 + 2, ry, mark, fg(if selected { GREEN } else { OVERLAY }).bg(bg));
                let label_style = if selected { fg(GREEN).bg(bg).add_modifier(Modifier::BOLD) } else { fg(TEXT).bg(bg) };
                put(buf, list_clip, inner.x as i32 + 5, ry, &opt.label, label_style);
                app.hits.push(Hit { rect: row_rect, action: Action::Focus(idx) });
            }
            Row::Field(q) => {
                let bg = if focused { SURFACE0 } else { MANTLE };
                let row_rect = Rect { x: inner.x, y: ry as u16, width: inner.width, height: 1 };
                match &pg.questions[*q] {
                    Question::Text { id, placeholder, .. } => {
                        let value = app.answer_str(id);
                        let box_w = (w - 4).min(52);
                        let field = Rect { x: inner.x + 2, y: ry as u16, width: box_w as u16, height: 1 };
                        fill(buf, field, if focused { SURFACE0 } else { CRUST });
                        let shown = if value.is_empty() { placeholder.clone() } else { value.clone() };
                        let st = if value.is_empty() { fg(OVERLAY).bg(if focused { SURFACE0 } else { CRUST }) } else { fg(TEXT).bg(if focused { SURFACE0 } else { CRUST }) };
                        put(buf, list_clip, field.x as i32 + 1, ry, &shown, st);
                        if focused && (app.tick / 6) % 2 == 0 {
                            let cx = field.x as i32 + 1 + if value.is_empty() { 0 } else { value.chars().count() as i32 };
                            put(buf, list_clip, cx, ry, "▏", fg(GREEN).bg(SURFACE0));
                        }
                        put(buf, list_clip, inner.x as i32, ry, if focused { "▌" } else { " " }, fg(gradient(0.5)).bg(MANTLE));
                    }
                    Question::Number { id, min, max, .. } => {
                        let v = app.answer_int(id);
                        if focused {
                            fill(buf, row_rect, SURFACE0);
                            put(buf, list_clip, inner.x as i32, ry, "▌", fg(gradient(0.5)).bg(SURFACE0));
                        }
                        put(buf, list_clip, inner.x as i32 + 2, ry, "◀", fg(if v > *min { CYAN } else { SURFACE1 }).bg(bg));
                        put(buf, list_clip, inner.x as i32 + 5, ry, &format!("{}", v), fg(GREEN).bg(bg).add_modifier(Modifier::BOLD));
                        put(buf, list_clip, inner.x as i32 + 9, ry, "▶", fg(if v < *max { CYAN } else { SURFACE1 }).bg(bg));
                        put(buf, list_clip, inner.x as i32 + 12, ry, &format!("{} to {}", min, max), fg(OVERLAY).bg(bg));
                    }
                    Question::Confirm { id, .. } => {
                        let on = app.answer_bool(id);
                        if focused {
                            fill(buf, row_rect, SURFACE0);
                            put(buf, list_clip, inner.x as i32, ry, "▌", fg(gradient(0.5)).bg(SURFACE0));
                        }
                        let (yes_bg, yes_fg) = if on { (GREEN, CRUST) } else { (SURFACE1, SUB) };
                        let (no_bg, no_fg) = if !on { (RED, CRUST) } else { (SURFACE1, SUB) };
                        put(buf, list_clip, inner.x as i32 + 2, ry, " Yes ", Style::new().fg(yes_fg).bg(yes_bg).add_modifier(Modifier::BOLD));
                        put(buf, list_clip, inner.x as i32 + 8, ry, " No ", Style::new().fg(no_fg).bg(no_bg).add_modifier(Modifier::BOLD));
                    }
                    _ => {}
                }
                app.hits.push(Hit { rect: row_rect, action: Action::Focus(idx) });
            }
        }
    }
    // scroll hints
    if scroll > 0 {
        put(buf, inner, inner.x as i32 + w - 2, list_top, "▲", fg(OVERLAY).bg(MANTLE));
    }
    if f_top + f_h < t - 0 && t - scroll > avail {
        put(buf, inner, inner.x as i32 + w - 2, list_bottom - 1, "▼", fg(OVERLAY).bg(MANTLE));
    }
    // detail strip: what the focused option means
    let sep_y = list_bottom;
    for x in 0..inner.width as i32 {
        put(buf, inner, inner.x as i32 + x, sep_y, "┄", fg(SURFACE1).bg(MANTLE));
    }
    let detail = match rws.get(app.focus) {
        Some(Row::Opt(q, i)) => match &pg.questions[*q] {
            Question::Choice { options, .. } | Question::Multi { options, .. } => options[*i].description.clone(),
            _ => String::new(),
        },
        Some(Row::Field(q)) => pg.questions[*q].help().to_string(),
        _ => String::new(),
    };
    for (k, line) in wrap(&detail, inner.width as usize - 4).iter().take(2).enumerate() {
        if k == 0 {
            put(buf, inner, inner.x as i32, sep_y + 1, "▸", fg(CYAN).bg(MANTLE));
        }
        put(buf, inner, inner.x as i32 + 3, sep_y + 1 + k as i32, line, fg(SUB).bg(MANTLE));
    }
}

fn review(buf: &mut Buffer, r: Rect, app: &mut App, phase: f32) {
    panel(buf, r, "Review", true, phase);
    let inner = Rect { x: r.x + 3, y: r.y + 1, width: r.width - 6, height: r.height - 2 };
    put(buf, inner, inner.x as i32, inner.y as i32 + 1, "Everything look right? Nothing has been changed yet.", fg(SUB).bg(MANTLE));
    let mut y = inner.y as i32 + 3;
    let label_w = app.spec.pages.iter().flat_map(|p| p.questions.iter()).filter(|q| q.id().is_some()).map(|q| q.label().chars().count()).max().unwrap_or(20) as i32 + 3;
    let max_y = (inner.y + inner.height) as i32 - 3;
    'outer: for page in app.spec.pages.clone() {
        for q in &page.questions {
            if q.id().is_none() {
                continue;
            }
            if y > max_y {
                put(buf, inner, inner.x as i32, y, "…", fg(OVERLAY).bg(MANTLE));
                break 'outer;
            }
            put(buf, inner, inner.x as i32, y, q.label(), fg(SUB).bg(MANTLE));
            let value = app.display(q);
            let shown: String = value.chars().take((inner.width as usize).saturating_sub(label_w as usize + 2)).collect();
            put(buf, inner, inner.x as i32 + label_w, y, &shown, fg(GREEN).bg(MANTLE));
            y += 1;
        }
    }
    let pulse = ((app.tick as f32 / 8.0).sin() * 0.5 + 0.5) * 0.6 + 0.4;
    let msg = "  Apply these choices  ";
    let bx = inner.x as i32;
    let by = (inner.y + inner.height) as i32 - 1;
    put(buf, inner, bx, by, msg, Style::new().fg(CRUST).bg(lerp(CYAN, GREEN, pulse)).add_modifier(Modifier::BOLD));
    put(buf, inner, bx + msg.len() as i32 + 2, by, "press enter    esc to go back", fg(OVERLAY).bg(MANTLE));
}
