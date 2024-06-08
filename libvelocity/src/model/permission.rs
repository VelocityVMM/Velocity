use std::fmt::Display;

use sqlx::SqlitePool;

use crate::error::{VErrorExt, VResult};
use crate::str;

/// A permission that can be given to users
/// to entitle them to privileged actions
#[derive(Debug)]
pub struct Permission {
    id: u32,
    /// The unique identifier of the permission
    pub name: String,
}

/// Errors that can occur when working with permissions
#[derive(Debug)]
pub enum PermissionError {
    /// A permission has not been found
    PermissionNotFound(String),
}

impl Permission {
    /// Creates a new permission WITHOUT creating it in the database
    /// # Arguments
    /// * `id` - The unique id of the permission
    /// * `name` - The unique name of the permission
    fn new(id: u32, name: String) -> Self {
        Self { id, name }
    }

    /// Returns the id of the permission
    pub fn id(&self) -> u32 {
        self.id
    }

    /// Ensures a permission exists in the database
    /// # Arguments
    /// * `db` - The database connection to ensure the permission in
    /// * `name` - The name of the permission
    pub async fn ensure(db: &SqlitePool, name: &str) -> VResult<Self> {
        Ok(match Self::try_select_name(db, name).await? {
            Some(permission) => permission,
            None => Self::create(db, name).await?,
        })
    }

    /// Creates a new permission in the supplied database
    ///
    /// # Warning
    /// This will fail if a permission with the same name does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database to create the new user in
    /// * `name` - The name of the permission to create
    pub async fn create(db: &SqlitePool, name: &str) -> VResult<Self> {
        sqlx::query!("INSERT INTO permissions (name) VALUES (?)", name,)
            .execute(db)
            .await
            .ctx(str!("Failed to insert permission '{name}'"))?;

        Self::select_name(db, name).await
    }

    /// Tries to select a permission by `name`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `name` - The name of the permission to select
    ///
    /// # Returns
    /// The permission or `None` if it does not exist
    pub async fn try_select_name(db: &SqlitePool, name: &str) -> VResult<Option<Self>> {
        let res = sqlx::query!("SELECT id, name FROM permissions WHERE name = ?", name)
            .fetch_optional(db)
            .await
            .ctx(str!("Failed to select permission '{name}'"))?;

        let res = match res {
            None => return Ok(None),
            Some(res) => res,
        };

        Ok(Some(Self::new(res.id as u32, res.name)))
    }

    /// Selects a permission by `name`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `name` - The name of the permission to select
    pub async fn select_name(db: &SqlitePool, name: &str) -> VResult<Self> {
        let user = Self::try_select_name(db, name).await?;

        match user {
            Some(user) => Ok(user),
            None => PermissionError::PermissionNotFound(name.to_owned())
                .ctx(str!("Selecting permission by name: '{name}'")),
        }
    }
}

impl Permission {
    /// Ensures all the default permissions Velocity expects
    /// do exist in the database
    /// # Arguments
    /// * `db` - The database connection to ensure the permissions in
    pub async fn ensure_default_permissions(db: &SqlitePool) -> VResult<()> {
        Ok(())
    }
}

impl Display for PermissionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::PermissionNotFound(name) => write!(f, "Permission '{name}' not found"),
        }
    }
}
