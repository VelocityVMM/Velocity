use std::{fmt::Display, io};

use axum::http::StatusCode;

use crate::model::{GroupError, PermissionError, UserError};

use super::VErrorIn;

/// All the possible types of errors that can occur within Velocity
#[derive(Debug)]
pub enum VErrorType {
    /// An error that originated from the `sqlx` crate
    SQLX(sqlx::Error),
    /// An error that has to do with users
    User(UserError),
    /// An error that has to do with groups
    Group(GroupError),
    /// An error that has to do with permissions
    Permission(PermissionError),
    /// A permission has been denied
    PermissionDenied(String),
    IO(io::Error),
}

impl Display for VErrorType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SQLX(e) => e.fmt(f),
            Self::User(e) => e.fmt(f),
            Self::Group(e) => e.fmt(f),
            Self::Permission(e) => e.fmt(f),
            Self::PermissionDenied(e) => write!(f, "Permission denied: {e}"),
            Self::IO(e) => e.fmt(f),
        }
    }
}

impl VErrorType {
    /// Returns the matching axum status code for the error
    pub fn get_statuscode(&self) -> StatusCode {
        match self {
            Self::PermissionDenied(_) => StatusCode::FORBIDDEN,
            _ => StatusCode::INTERNAL_SERVER_ERROR,
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

impl From<GroupError> for VErrorType {
    fn from(value: GroupError) -> Self {
        Self::Group(value)
    }
}
impl VErrorIn for GroupError {}

impl From<PermissionError> for VErrorType {
    fn from(value: PermissionError) -> Self {
        Self::Permission(value)
    }
}
impl VErrorIn for PermissionError {}

impl From<io::Error> for VErrorType {
    fn from(value: io::Error) -> Self {
        Self::IO(value)
    }
}
impl VErrorIn for io::Error {}
