use std::time::{Duration, SystemTime};

use serde::{Serialize, Serializer};

use crate::api::ToJSONPanic;

/// An authentication key to access privileged actions
#[derive(Serialize, Clone)]
pub struct Authkey {
    authkey: String,
    #[serde(serialize_with = "serialize_system_time")]
    expires: SystemTime,
    #[serde(skip)]
    uid: u32,
}

impl Authkey {
    /// Generates a new authkey
    /// # Arguments
    /// * `uid` - The user id to generate the authkey for
    /// * `validity` - The time the new authkey is valid from now on
    pub fn generate_now(uid: u32, validity: Duration) -> Self {
        let uuid = uuid::Uuid::new_v4().to_string();
        let expires = SystemTime::now() + validity;

        Self {
            authkey: uuid,
            expires,
            uid,
        }
    }

    /// Returns the key string for this authkey
    pub fn key(&self) -> &str {
        &self.authkey
    }

    /// Returns the `uid` for the user this key authenticates
    pub fn uid(&self) -> u32 {
        self.uid
    }

    /// Returns the time this key expires
    pub fn expires(&self) -> &SystemTime {
        &self.expires
    }

    /// Check if the key is valid at time of calling
    pub fn is_valid_now(&self) -> bool {
        SystemTime::now() < self.expires
    }
}

impl ToJSONPanic for Authkey {}

/// Serde serialization for [`SystemTime`]
fn serialize_system_time<S: Serializer>(
    time: &SystemTime,
    serializer: S,
) -> Result<S::Ok, S::Error> {
    serializer.serialize_u64(
        time.duration_since(SystemTime::UNIX_EPOCH)
            .expect("Convert duration to UNIX timestamp")
            .as_secs(),
    )
}
