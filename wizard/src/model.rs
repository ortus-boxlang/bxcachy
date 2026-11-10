//! The pages the wizard shows (read from JSON) and the answers it returns.
use serde::Deserialize;

#[derive(Deserialize, Clone, Debug)]
#[allow(dead_code)] // `title` is part of the pages contract even though the splash draws its own wordmark
pub struct Spec {
    pub title: String,
    #[serde(default)]
    pub tagline: String,
    #[serde(default)]
    pub version: String,
    pub pages: Vec<Page>,
}

#[derive(Deserialize, Clone, Debug)]
#[allow(dead_code)] // `id` names the page for the caller
pub struct Page {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub intro: String,
    pub questions: Vec<Question>,
}

#[derive(Deserialize, Clone, Debug)]
pub struct Opt {
    pub value: String,
    pub label: String,
    #[serde(default)]
    pub description: String,
    /// Options with the same group are listed under one heading.
    #[serde(default)]
    pub group: String,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum Question {
    Choice { id: String, label: String, #[serde(default)] help: String, options: Vec<Opt>, #[serde(default)] default: Option<String> },
    Multi { id: String, label: String, #[serde(default)] help: String, options: Vec<Opt>, #[serde(default)] default: Vec<String> },
    Text { id: String, label: String, #[serde(default)] help: String, #[serde(default)] default: String, #[serde(default)] placeholder: String },
    Number { id: String, label: String, #[serde(default)] help: String, min: i64, max: i64, default: i64 },
    Confirm { id: String, label: String, #[serde(default)] help: String, default: bool },
    Info { label: String, #[serde(default)] help: String },
}

impl Question {
    pub fn id(&self) -> Option<&str> {
        match self {
            Question::Choice { id, .. } | Question::Multi { id, .. } | Question::Text { id, .. } | Question::Number { id, .. } | Question::Confirm { id, .. } => Some(id),
            Question::Info { .. } => None,
        }
    }
    pub fn label(&self) -> &str {
        match self {
            Question::Choice { label, .. } | Question::Multi { label, .. } | Question::Text { label, .. } | Question::Number { label, .. } | Question::Confirm { label, .. } | Question::Info { label, .. } => label,
        }
    }
    pub fn help(&self) -> &str {
        match self {
            Question::Choice { help, .. } | Question::Multi { help, .. } | Question::Text { help, .. } | Question::Number { help, .. } | Question::Confirm { help, .. } | Question::Info { help, .. } => help,
        }
    }
}
