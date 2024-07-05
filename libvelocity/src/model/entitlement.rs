use std::fmt::Display;

/// Lists all known permission entitlements available in Velocity
pub enum Entitlement {
    /// Entitles users to create new users in
    /// the Velocity system
    ///
    /// This entitlement is global
    UserCreate,
    /// Entitles users to remove other users
    /// from the Velocity system
    ///
    /// This entitlement is global
    UserRemove,
}

impl Entitlement {
    /// Returns the permission string for this entitlement
    pub fn str(&self) -> &'static str {
        match self {
            Self::UserCreate => "velocity.user.create",
            Self::UserRemove => "velocity.user.remove",
        }
    }
}

impl Display for Entitlement {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.str())
    }
}
