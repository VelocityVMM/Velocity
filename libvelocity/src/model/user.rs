use std::fmt::Display;

use sqlx::SqlitePool;

use crate::{
    error::{VErrorExt, VResult},
    str,
};

/// A user in the Velocity system
#[derive(Debug, Clone)]
pub struct User {
    /// The user id is the primary key, so it is guarded
    uid: u32,
    /// The username of the user
    pub username: String,
    /// The password hash the user can authenticate with
    pub pwhash: String,
}

/// Errors that can occur when working with users
#[derive(Debug)]
pub enum UserError {
    /// A user id (uid) has not been found
    UserIDNotFound(u32),
    /// A username has not been found
    UsernameNotFound(String),
}

impl User {
    /// Creates a new in-memory user without a backing database entry
    ///
    /// # Warning
    /// The created user does not have any backing database entry -
    /// any actions that require a database connection to work may error
    /// with inexplicable errors
    ///
    /// # Arguments
    /// * `uid` - The user id to assign
    /// * `username` - The username to assign
    /// * `pwhash` - The password hash the user can authenticate with
    fn new(uid: u32, username: String, pwhash: String) -> Self {
        Self {
            uid,
            username,
            pwhash,
        }
    }

    /// Returns the user id of the user
    pub fn uid(&self) -> u32 {
        self.uid
    }

    /// Creates a new user in the supplied database
    ///
    /// # Warning
    /// This will fail if a user with the same name does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database to create the new user in
    /// * `username` - The unique username to use for the new user
    /// * `pwhash` - The password hash the user can authenticate with
    pub async fn create(db: &SqlitePool, username: &str, pwhash: &str) -> VResult<User> {
        sqlx::query!(
            "INSERT INTO users (username, pwhash) VALUES (?, ?)",
            username,
            pwhash
        )
        .execute(db)
        .await
        .ctx(str!("Failed to insert user '{username}'"))?;

        User::select_username(db, username).await
    }

    /// Creates a new user in the supplied database with a specific user id
    ///
    /// # Warning
    /// This will fail if a user with the same name does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database to create the new user in
    /// * `username` - The unique username to use for the new user
    /// * `pwhash` - The password hash the user can authenticate with
    pub async fn create_with_uid(
        db: &SqlitePool,
        uid: u32,
        username: &str,
        pwhash: &str,
    ) -> VResult<User> {
        sqlx::query!(
            "INSERT INTO users (uid, username, pwhash) VALUES (?, ?, ?)",
            uid,
            username,
            pwhash
        )
        .execute(db)
        .await
        .ctx(str!("Failed to insert user '{username}' ({uid})"))?;

        User::select_username(db, username).await
    }

    /// Tries to select a user by `username`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `username` - The username of the user to select
    ///
    /// # Returns
    /// The user or `None` if it does not exist
    pub async fn try_select_username(db: &SqlitePool, username: &str) -> VResult<Option<User>> {
        let res = sqlx::query!(
            "SELECT uid, username, pwhash FROM users WHERE username = ?",
            username
        )
        .fetch_optional(db)
        .await
        .ctx(str!("Failed to select user '{username}'"))?;

        let res = match res {
            None => return Ok(None),
            Some(res) => res,
        };

        Ok(Some(User::new(res.uid as u32, res.username, res.pwhash)))
    }

    /// Selects a user by `username`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `username` - The username of the user to select
    pub async fn select_username(db: &SqlitePool, username: &str) -> VResult<User> {
        let user = Self::try_select_username(db, username).await?;

        match user {
            Some(user) => Ok(user),
            None => UserError::UsernameNotFound(username.to_owned())
                .ctx(str!("Selecting user by username: '{username}'")),
        }
    }

    /// Tries to select a user by `uid`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `uid` - The user id of the user to select
    ///
    /// # Returns
    /// The user or `None` if it doesn't exist
    pub async fn try_select_uid(db: &SqlitePool, uid: u32) -> VResult<Option<User>> {
        let res = sqlx::query!("SELECT uid, username, pwhash FROM users WHERE uid = ?", uid)
            .fetch_optional(db)
            .await
            .ctx(str!("Failed to select user {uid}"))?;

        let res = match res {
            None => return Ok(None),
            Some(res) => res,
        };

        Ok(Some(User::new(res.uid as u32, res.username, res.pwhash)))
    }

    /// Selects a user by `uid`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `uid` - The user id of the user to select
    pub async fn select_uid(db: &SqlitePool, uid: u32) -> VResult<User> {
        let user = Self::try_select_uid(db, uid).await?;

        match user {
            Some(user) => Ok(user),
            None => UserError::UserIDNotFound(uid).ctx(str!("Selecting user by uid: {uid}")),
        }
    }

    /// Applies the changes from `self` to the database entry with the same `uid`
    ///
    /// # Arguments
    /// * `db` - The database to apply the new values to
    pub async fn apply(&self, db: &SqlitePool) -> VResult<()> {
        sqlx::query!(
            "UPDATE users SET username = ?, pwhash = ? WHERE uid = ?",
            self.username,
            self.pwhash,
            self.uid
        )
        .execute(db)
        .await
        .ctx(str!("Failed to update user"))?;

        Ok(())
    }
}

impl Display for User {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} ({})", self.username, self.uid)
    }
}

impl Display for UserError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UserIDNotFound(uid) => write!(f, "User ID {uid} not found"),
            Self::UsernameNotFound(username) => write!(f, "Username '{username}' not found"),
        }
    }
}
