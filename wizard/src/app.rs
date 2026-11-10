//! Wizard state and behaviour: which screen is showing, the answers so far, and what each key or click does.
use crate::model::{Page, Question, Spec};
use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::layout::Rect;
use serde_json::{json, Value};
use std::collections::BTreeMap;

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Screen {
    Welcome,
    Page(usize),
    Review,
}

#[derive(PartialEq, Debug)]
pub enum Outcome {
    Running,
    Done,
    Cancelled,
}

/// One line of a page: a question's heading, an option or field to act on, plain info, or spacing.
#[derive(Clone, PartialEq, Debug)]
pub enum Row {
    Heading(usize),
    Group(String),
    Opt(usize, usize),
    Field(usize),
    Info(usize),
    Space,
}

impl Row {
    pub fn focusable(&self) -> bool {
        matches!(self, Row::Opt(..) | Row::Field(_))
    }
    pub fn question(&self) -> Option<usize> {
        match self {
            Row::Heading(q) | Row::Opt(q, _) | Row::Field(q) | Row::Info(q) => Some(*q),
            _ => None,
        }
    }
}

/// What a click on a screen region does.
#[derive(Clone, Debug)]
pub enum Action {
    GotoPage(usize),
    GotoReview,
    Focus(usize),
}

pub struct Hit {
    pub rect: Rect,
    pub action: Action,
}

pub struct App {
    pub spec: Spec,
    pub screen: Screen,
    pub furthest: usize,
    pub focus: usize,
    pub answers: BTreeMap<String, Value>,
    pub tick: u64,
    pub hits: Vec<Hit>,
    pub outcome: Outcome,
    /// The screen last drawn and the tick it appeared at (drives the fade-in).
    pub last_screen: Screen,
    pub changed_at: u64,
}

/// The rows of a page, in order.
pub fn rows(page: &Page) -> Vec<Row> {
    let mut out = Vec::new();
    for (q, question) in page.questions.iter().enumerate() {
        if !out.is_empty() {
            out.push(Row::Space);
        }
        match question {
            Question::Info { .. } => out.push(Row::Info(q)),
            Question::Choice { options, .. } | Question::Multi { options, .. } => {
                out.push(Row::Heading(q));
                let mut group = String::new();
                for (i, opt) in options.iter().enumerate() {
                    if opt.group != group {
                        group = opt.group.clone();
                        if !group.is_empty() {
                            out.push(Row::Group(group.clone()));
                        }
                    }
                    out.push(Row::Opt(q, i));
                }
            }
            _ => {
                out.push(Row::Heading(q));
                out.push(Row::Field(q));
            }
        }
    }
    out
}

impl App {
    pub fn new(spec: Spec, preset: BTreeMap<String, Value>) -> App {
        let mut answers = BTreeMap::new();
        for page in &spec.pages {
            for q in &page.questions {
                if let Some(id) = q.id() {
                    let v = match q {
                        Question::Choice { default, options, .. } => json!(default.clone().or_else(|| options.first().map(|o| o.value.clone())).unwrap_or_default()),
                        Question::Multi { default, .. } => json!(default),
                        Question::Text { default, .. } => json!(default),
                        Question::Number { default, .. } => json!(default),
                        Question::Confirm { default, .. } => json!(default),
                        Question::Info { .. } => continue,
                    };
                    answers.insert(id.to_string(), v);
                }
            }
        }
        for (k, v) in preset {
            if answers.contains_key(&k) {
                answers.insert(k, v);
            }
        }
        App { spec, screen: Screen::Welcome, furthest: 0, focus: 0, answers, tick: 0, hits: Vec::new(), outcome: Outcome::Running, last_screen: Screen::Welcome, changed_at: 0 }
    }

    pub fn page(&self) -> Option<&Page> {
        match self.screen {
            Screen::Page(i) => self.spec.pages.get(i),
            _ => None,
        }
    }

    pub fn page_rows(&self) -> Vec<Row> {
        self.page().map(rows).unwrap_or_default()
    }

    pub fn answer_str(&self, id: &str) -> String {
        self.answers.get(id).and_then(|v| v.as_str()).unwrap_or("").to_string()
    }
    pub fn answer_list(&self, id: &str) -> Vec<String> {
        self.answers.get(id).and_then(|v| v.as_array()).map(|a| a.iter().filter_map(|x| x.as_str().map(String::from)).collect()).unwrap_or_default()
    }
    pub fn answer_int(&self, id: &str) -> i64 {
        self.answers.get(id).and_then(|v| v.as_i64()).unwrap_or(0)
    }
    pub fn answer_bool(&self, id: &str) -> bool {
        self.answers.get(id).and_then(|v| v.as_bool()).unwrap_or(false)
    }

    /// A readable value for the review screen.
    pub fn display(&self, q: &Question) -> String {
        let Some(id) = q.id() else { return String::new() };
        match q {
            Question::Choice { options, .. } => {
                let v = self.answer_str(id);
                options.iter().find(|o| o.value == v).map(|o| o.label.clone()).unwrap_or(v)
            }
            Question::Multi { options, .. } => {
                let vs = self.answer_list(id);
                if vs.is_empty() {
                    "none".to_string()
                } else {
                    vs.iter().map(|v| options.iter().find(|o| &o.value == v).map(|o| o.label.clone()).unwrap_or_else(|| v.clone())).collect::<Vec<_>>().join(", ")
                }
            }
            Question::Text { .. } => {
                let v = self.answer_str(id);
                if v.is_empty() { "not set".to_string() } else { v }
            }
            Question::Number { .. } => self.answer_int(id).to_string(),
            Question::Confirm { .. } => if self.answer_bool(id) { "yes".to_string() } else { "no".to_string() },
            Question::Info { .. } => String::new(),
        }
    }

    pub fn goto_page(&mut self, i: usize) {
        if i < self.spec.pages.len() {
            self.screen = Screen::Page(i);
            self.furthest = self.furthest.max(i);
            self.focus = self.page_rows().iter().position(Row::focusable).unwrap_or(0);
        }
    }

    pub fn next_page(&mut self) {
        match self.screen {
            Screen::Welcome => self.goto_page(0),
            Screen::Page(i) if i + 1 < self.spec.pages.len() => self.goto_page(i + 1),
            Screen::Page(_) => {
                self.furthest = self.spec.pages.len();
                self.screen = Screen::Review;
            }
            Screen::Review => self.outcome = Outcome::Done,
        }
    }

    pub fn prev_page(&mut self) {
        match self.screen {
            Screen::Page(i) if i > 0 => self.goto_page(i - 1),
            Screen::Page(_) => self.screen = Screen::Welcome,
            Screen::Review => self.goto_page(self.spec.pages.len() - 1),
            Screen::Welcome => {}
        }
    }

    fn move_focus(&mut self, down: bool) {
        let rows = self.page_rows();
        let mut i = self.focus as isize;
        loop {
            i += if down { 1 } else { -1 };
            if i < 0 || i as usize >= rows.len() {
                return;
            }
            if rows[i as usize].focusable() {
                self.focus = i as usize;
                return;
            }
        }
    }

    fn focused_row(&self) -> Option<Row> {
        self.page_rows().get(self.focus).cloned()
    }

    /// Select or toggle whatever has focus (space, or a click).
    pub fn activate(&mut self) {
        let Some(page) = self.page().cloned() else { return };
        match self.focused_row() {
            Some(Row::Opt(q, i)) => match &page.questions[q] {
                Question::Choice { id, options, .. } => {
                    self.answers.insert(id.clone(), json!(options[i].value));
                }
                Question::Multi { id, options, .. } => {
                    let mut vs = self.answer_list(id);
                    let v = options[i].value.clone();
                    if let Some(p) = vs.iter().position(|x| *x == v) {
                        vs.remove(p);
                    } else {
                        vs.push(v);
                    }
                    self.answers.insert(id.clone(), json!(vs));
                }
                _ => {}
            },
            Some(Row::Field(q)) => {
                if let Question::Confirm { id, .. } = &page.questions[q] {
                    let now = !self.answer_bool(id);
                    self.answers.insert(id.clone(), json!(now));
                }
            }
            _ => {}
        }
    }

    /// Enter: finish this question and go to the next one, or to the next page after the last.
    fn advance(&mut self) {
        let Some(page) = self.page().cloned() else { return self.next_page() };
        let rows = rows(&page);
        let Some(Row::Opt(q, _) | Row::Field(q)) = rows.get(self.focus).cloned() else { return self.next_page() };
        if matches!(page.questions[q], Question::Choice { .. }) {
            self.activate();
        }
        match rows.iter().enumerate().skip(self.focus + 1).find(|(_, r)| r.focusable() && r.question() != Some(q)) {
            Some((i, _)) => self.focus = i,
            None => self.next_page(),
        }
    }

    fn adjust_number(&mut self, delta: i64) {
        let Some(page) = self.page().cloned() else { return };
        if let Some(Row::Field(q)) = self.focused_row() {
            if let Question::Number { id, min, max, .. } = &page.questions[q] {
                let v = (self.answer_int(id) + delta).clamp(*min, *max);
                self.answers.insert(id.clone(), json!(v));
            }
        }
    }

    fn on_text_field(&self) -> Option<String> {
        let page = self.page()?;
        match self.focused_row() {
            Some(Row::Field(q)) => match &page.questions[q] {
                Question::Text { id, .. } => Some(id.clone()),
                _ => None,
            },
            _ => None,
        }
    }

    pub fn on_key(&mut self, key: KeyEvent) {
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.outcome = Outcome::Cancelled;
            return;
        }
        if self.screen == Screen::Welcome {
            match key.code {
                KeyCode::Enter | KeyCode::Char(' ') => self.next_page(),
                KeyCode::Esc | KeyCode::Char('q') => self.outcome = Outcome::Cancelled,
                _ => {}
            }
            return;
        }
        if self.screen == Screen::Review {
            match key.code {
                KeyCode::Enter => self.outcome = Outcome::Done,
                KeyCode::Esc | KeyCode::Left | KeyCode::BackTab | KeyCode::PageUp => self.prev_page(),
                _ => {}
            }
            return;
        }
        if let Some(id) = self.on_text_field() {
            match key.code {
                KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                    let mut s = self.answer_str(&id);
                    s.push(c);
                    self.answers.insert(id, json!(s));
                    return;
                }
                KeyCode::Backspace => {
                    let mut s = self.answer_str(&id);
                    s.pop();
                    self.answers.insert(id, json!(s));
                    return;
                }
                KeyCode::Char('u') => {
                    self.answers.insert(id, json!(""));
                    return;
                }
                _ => {}
            }
        }
        match key.code {
            KeyCode::Up => self.move_focus(false),
            KeyCode::Down => self.move_focus(true),
            KeyCode::Char('k') => self.move_focus(false),
            KeyCode::Char('j') => self.move_focus(true),
            KeyCode::Char(' ') => self.activate(),
            KeyCode::Enter => self.advance(),
            KeyCode::Left | KeyCode::Char('-') => self.adjust_number(-1),
            KeyCode::Right | KeyCode::Char('+') => self.adjust_number(1),
            KeyCode::Tab | KeyCode::PageDown => self.next_page(),
            KeyCode::BackTab | KeyCode::PageUp | KeyCode::Esc => self.prev_page(),
            _ => {}
        }
    }

    pub fn on_click(&mut self, x: u16, y: u16) {
        let hit = self.hits.iter().rev().find(|h| x >= h.rect.x && x < h.rect.x + h.rect.width && y >= h.rect.y && y < h.rect.y + h.rect.height).map(|h| h.action.clone());
        match hit {
            Some(Action::GotoPage(i)) if i <= self.furthest => self.goto_page(i),
            Some(Action::GotoReview) if self.furthest >= self.spec.pages.len() => self.screen = Screen::Review,
            Some(Action::Focus(r)) => {
                self.focus = r;
                self.activate();
            }
            _ => {}
        }
    }

    pub fn answers_json(&self) -> String {
        serde_json::to_string_pretty(&self.answers).unwrap_or_else(|_| "{}".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::crossterm::event::{KeyEventKind, KeyEventState};

    fn key(code: KeyCode) -> KeyEvent {
        KeyEvent { code, modifiers: KeyModifiers::NONE, kind: KeyEventKind::Press, state: KeyEventState::NONE }
    }

    fn app() -> App {
        let mut a = App::new(crate::demo::spec(), BTreeMap::new());
        a.on_key(key(KeyCode::Enter)); // leave the welcome screen
        a
    }

    #[test]
    fn defaults_come_from_the_pages_and_presets_override_them() {
        let a = App::new(crate::demo::spec(), BTreeMap::new());
        assert_eq!(a.answer_str("desktops"), "both");
        assert_eq!(a.answer_int("workspaces"), 2);
        assert!(!a.answer_bool("natural_scroll"));
        assert_eq!(a.answer_list("layouts"), vec!["us-intl", "es"]);
        let mut preset = BTreeMap::new();
        preset.insert("desktops".to_string(), json!("plasma"));
        preset.insert("not_a_question".to_string(), json!("x"));
        let b = App::new(crate::demo::spec(), preset);
        assert_eq!(b.answer_str("desktops"), "plasma");
        assert!(!b.answers.contains_key("not_a_question"));
    }

    #[test]
    fn enter_leaves_the_welcome_screen_and_focuses_the_first_option() {
        let a = app();
        assert_eq!(a.screen, Screen::Page(0));
        assert!(a.page_rows()[a.focus].focusable());
    }

    #[test]
    fn space_selects_a_choice_and_enter_moves_to_the_next_question() {
        let mut a = app();
        a.on_key(key(KeyCode::Down));
        a.on_key(key(KeyCode::Char(' ')));
        assert_eq!(a.answer_str("desktops"), "plasma");
        let before = a.focus;
        a.on_key(key(KeyCode::Enter));
        assert!(a.focus > before);
        assert_eq!(a.page_rows()[a.focus].question(), Some(1));
    }

    #[test]
    fn a_multi_choice_toggles_on_and_off() {
        let mut a = app();
        a.goto_page(2); // input
        a.on_key(key(KeyCode::Down)); // second option: English (US)
        a.on_key(key(KeyCode::Char(' ')));
        assert!(a.answer_list("layouts").contains(&"us".to_string()));
        a.on_key(key(KeyCode::Char(' ')));
        assert!(!a.answer_list("layouts").contains(&"us".to_string()));
    }

    #[test]
    fn numbers_stay_inside_their_range() {
        let mut a = app();
        let n = a.page_rows().iter().position(|r| matches!(r, Row::Field(_))).unwrap();
        a.focus = n;
        for _ in 0..30 {
            a.on_key(key(KeyCode::Right));
        }
        assert_eq!(a.answer_int("workspaces"), 10);
        for _ in 0..30 {
            a.on_key(key(KeyCode::Left));
        }
        assert_eq!(a.answer_int("workspaces"), 1);
    }

    #[test]
    fn text_fields_take_typing_and_backspace_and_do_not_move_focus() {
        let mut a = app();
        a.goto_page(3); // developer
        for c in "Luis".chars() {
            a.on_key(key(KeyCode::Char(c)));
        }
        assert_eq!(a.answer_str("git_name"), "Luis");
        a.on_key(key(KeyCode::Backspace));
        assert_eq!(a.answer_str("git_name"), "Lui");
        a.on_key(key(KeyCode::Char('j'))); // typed, not a move
        assert_eq!(a.answer_str("git_name"), "Luij");
    }

    #[test]
    fn the_last_page_leads_to_review_and_enter_there_finishes() {
        let mut a = app();
        a.goto_page(a.spec.pages.len() - 1);
        a.next_page();
        assert_eq!(a.screen, Screen::Review);
        a.on_key(key(KeyCode::Enter));
        assert_eq!(a.outcome, Outcome::Done);
        let json: serde_json::Value = serde_json::from_str(&a.answers_json()).unwrap();
        assert_eq!(json["desktops"], "both");
    }

    #[test]
    fn ctrl_c_cancels_from_anywhere() {
        let mut a = app();
        a.on_key(KeyEvent { code: KeyCode::Char('c'), modifiers: KeyModifiers::CONTROL, kind: KeyEventKind::Press, state: KeyEventState::NONE });
        assert_eq!(a.outcome, Outcome::Cancelled);
    }

    #[test]
    fn going_back_from_the_first_page_returns_to_the_welcome_screen() {
        let mut a = app();
        a.on_key(key(KeyCode::Esc));
        assert_eq!(a.screen, Screen::Welcome);
    }

    #[test]
    fn review_shows_readable_values() {
        let a = App::new(crate::demo::spec(), BTreeMap::new());
        let q = &a.spec.pages[0].questions[0];
        assert_eq!(a.display(q), "Both");
    }
}
