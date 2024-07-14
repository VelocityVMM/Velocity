use std::{fmt::Display, io};

use axum::http::StatusCode;

use crate::model::{GroupError, PermissionError, UserError};

use super::VErrorIn;
use crate::api::IntoAPIError;

/// All the possible types of errors that can occur within Velocity
#[derive(Debug)]
#[repr(u16)]
pub enum VErrorType {
    /// An error that has to do with users
    User(UserError) = 0x10,
    /// An error that has to do with groups
    Group(GroupError) = 0x20,
    /// An error that has to do with permissions
    Permission(PermissionError) = 0x30,
    /// An error that originated from the `sqlx` crate
    SQLX(sqlx::Error) = 0xFF00,
    /// An IO error
    IO(io::Error),
}

impl Display for VErrorType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::SQLX(e) => e.fmt(f),
            Self::User(e) => e.fmt(f),
            Self::Group(e) => e.fmt(f),
            Self::Permission(e) => e.fmt(f),
            Self::IO(e) => e.fmt(f),
        }
    }
}

impl VErrorType {
    /// Returns the matching axum status code for the error
    pub fn get_statuscode(&self) -> StatusCode {
        match self {
            Self::User(e) => e.get_status(),
            Self::Group(e) => e.get_status(),
            Self::Permission(e) => e.get_status(),

            _ => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    pub fn get_code(&self) -> u32 {
        let self_code = unsafe { *(self as *const Self as *const u16) };

        let sub_code: u16 = match self {
            Self::User(e) => e.get_code(),
            Self::Group(e) => e.get_code(),
            Self::Permission(e) => e.get_code(),
            _ => 0xFFFF,
        };

        (self_code as u32) << 16 | sub_code as u32
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
