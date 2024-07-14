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
    /// Entitles users to list all registered
    /// users on the Velocity system
    ///
    /// This entitlement is global
    UserList,
    /// Entitles a user to create new groups
    /// within the group he has been granted
    /// this permission on
    GroupCreate,
    /// Entitles a user to remove groups
    /// from the group he has been granted
    /// this permission on
    GroupRemove,
}

impl Entitlement {
    /// Returns the permission string for this entitlement
    pub fn str(&self) -> &'static str {
        match self {
            Self::UserCreate => "velocity.user.create",
            Self::UserRemove => "velocity.user.remove",
            Self::UserList => "velocity.user.list",
            Self::GroupCreate => "velocity.group.create",
            Self::GroupRemove => "velocity.group.remove",
        }
    }
}

impl Display for Entitlement {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.str())
    }
}
