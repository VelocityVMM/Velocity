use std::fmt::Display;

use crate::model::UserError;

use super::VErrorIn;

/// All the possible types of errors that can occur within Velocity
#[derive(Debug)]
pub enum VErrorType {
    /// An error that originated from the `sqlx` crate
    SQLX(sqlx::Error),
    /// An error that has to do with users
    User(UserError),
}

impl Display for VErrorType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SQLX(e) => e.fmt(f),
            Self::User(e) => e.fmt(f),
        }
    }
}

impl From<sqlx::Error> for VErrorType {
    fn from(value: sqlx::Error) -> Self {
        Self::SQLX(value)
    }
}
impl VErrorIn for sqlx::Error {}

impl From<UserError> for VErrorType {
    fn from(value: UserError) -> Self {
        Self::User(value)
    }
}
impl VErrorIn for UserError {}
