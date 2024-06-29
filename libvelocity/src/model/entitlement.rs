use std::fmt::Display;

/// Lists all known permission entitlements available in Velocity
pub enum Entitlement {
    /// Entitles users to create new users in
    /// the Velocity system
    ///
    /// This entitlement is global
    UserCreate,
}

impl Entitlement {
    /// Returns the permission string for this entitlement
    pub fn str(&self) -> &'static str {
        match self {
            Self::UserCreate => "velocity.user.create",
        }
    }
}

impl Display for Entitlement {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.str())
    }
}
