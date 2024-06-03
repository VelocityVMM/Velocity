use std::{collections::HashMap, time::Duration};

use log::trace;
use sqlx::SqlitePool;

use crate::error::VResult;

use super::{Authkey, User};

/// Manages active authentication sessions
#[derive(Default)]
pub struct AuthManager {
    authkeys: HashMap<String, Authkey>,
}

impl AuthManager {
    /// Drops a registered key if it exists
    /// # Arguments
    /// * `key` - The key string of the key to drop
    /// # Returns
    /// The key if it was registered, otherwise `None`
    pub fn drop_key(&mut self, key: &str) -> Option<Authkey> {
        self.authkeys.remove(key)
    }

    /// Searches for a registered, valid authkey and drops it in favor of a new one
    /// # Arguments
    /// * `key` - The key string to refresh
    /// * `validity` - The time the new key should be valid for
    /// # Returns
    /// The new key or `None` if there was no registered, valid key
    pub fn refresh_key(&mut self, key: &str, validity: Duration) -> Option<Authkey> {
        let old_key = self.authkeys.remove(key)?;

        if !old_key.is_valid_now() {
            trace!(
                "User {} tried to refresh expired key {}",
                old_key.uid(),
                old_key.key()
            );
            return None;
        }

        let key = Authkey::generate_now(old_key.uid(), validity);

        trace!(
            "Refreshed authkey {} of user {} to {}",
            old_key.key(),
            old_key.uid(),
            key.key()
        );

        self.register_key(key.clone());

        Some(key)
    }

    /// Returns the user id associated with a key
    /// # Arguments
    /// * `key` - The key string to search for
    /// # Returns
    /// The `uid` value for the key or `None` if the was no valid, registered key
    pub fn get_uid(&self, key: &str) -> Option<u32> {
        let key = self.authkeys.get(key)?;

        if !key.is_valid_now() {
            trace!(
                "User {} tried to retrieve expired key {}",
                key.uid(),
                key.key()
            );
            return None;
        }

        Some(key.uid())
    }

    /// Returns the user associated with a key
    /// # Arguments
    /// * `key` - The key string to search for
    /// # Returns
    /// The user for the key or `None` if the was no valid, registered key
    pub async fn get_user(&self, key: &str, db: &SqlitePool) -> VResult<Option<User>> {
        let uid = match self.get_uid(key) {
            None => return Ok(None),
            Some(uid) => uid,
        };

        Ok(Some(User::select_uid(db, uid).await?))
    }

    /// Register a new authkey
    /// # Arguments
    /// * `key` - The key to register
    pub fn register_key(&mut self, key: Authkey) {
        self.authkeys.insert(key.key().to_string(), key);
    }

    /// Generate and register a new authkey
    /// # Arguments
    /// * `uid` - The user id to authenticate with the new key
    /// * `validity` - The time the new key should be valid for from `now`
    /// # Returns
    /// The newly generated and authenticated key
    pub fn generate_now(&mut self, uid: u32, validity: Duration) -> Authkey {
        let key = Authkey::generate_now(uid, validity);

        trace!("Activated authkey {} for user {uid}", key.key());

        self.register_key(key.clone());

        key
    }
}
