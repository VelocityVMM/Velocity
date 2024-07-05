use std::fmt::Display;

use log::debug;
use sqlx::SqlitePool;

use crate::error::{VErrorExt, VResult};
use crate::str;

use super::{Entitlement, Group, User};

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

    /// Grants `user` the permission
    ///
    /// # Warning
    /// This will fail if a grant does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database connection to create the new permission link in
    /// * `user` - The user to grant the permission
    /// * `group` - The group to grant the permission on
    pub async fn grant(&self, db: &SqlitePool, user: &User, group: &Group) -> VResult<()> {
        let uid = user.uid();
        let gid = group.gid();

        sqlx::query!(
            "INSERT INTO userpermissions (permission, uid, gid) VALUES (?, ?, ?)",
            self.name,
            uid,
            gid,
        )
        .execute(db)
        .await
        .ctx(str!(
            "Failed to give permission '{}' on group '{}' to '{}'",
            self.name,
            group.groupname,
            user.username
        ))?;

        debug!(
            "Granted '{}' permission '{}' on group '{}'({gid})",
            user.username, self.name, group.groupname
        );

        Ok(())
    }

    /// Grants `user` the permission if not done already
    ///
    /// This function differs from [Self::grant] in that it checks
    /// if the grant is already existing
    ///
    /// # Arguments
    /// * `db` - The database connection to create the new permission link in
    /// * `user` - The user to grant the permission
    /// * `group` - The group to grant the permission on
    pub async fn ensure_granted(&self, db: &SqlitePool, user: &User, group: &Group) -> VResult<()> {
        if !self.is_granted(db, user, group).await? {
            self.grant(db, user, group).await?;
        }

        Ok(())
    }

    /// Checks if `user` has been granted this permission on `group`
    ///
    /// # Arguments
    /// * `db` - The database connection to execute the query on
    /// * `user` - The user to check the permissions of
    /// * `group` - The group to check for granted permission
    pub async fn is_granted(&self, db: &SqlitePool, user: &User, group: &Group) -> VResult<bool> {
        Self::is_granted_raw(db, &self.name, user.uid(), group.gid()).await
    }

    /// Checks if `user` has been granted this permission in any group
    ///
    /// This function checks if the permission is granted on **any**
    /// group in the Velocity system
    ///
    /// # Arguments
    /// * `db` - The database connection to execute the query on
    /// * `user` - The user to check the permissions of
    pub async fn is_granted_somewhere(&self, db: &SqlitePool, user: &User) -> VResult<bool> {
        Self::is_granted_somewhere_raw(db, &self.name, user.uid()).await
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

    /// Checks if `user` has been granted `permission` on `group`
    ///
    /// # Arguments
    /// * `db` - The database connection to execute the query on
    /// * `permission` - The permission to check for
    /// * `uid` - The user id to check the permissions of
    /// * `gid` - The group id to check for granted permission
    pub async fn is_granted_raw(
        db: &SqlitePool,
        permission: &str,
        uid: u32,
        gid: u32,
    ) -> VResult<bool> {
        let res = sqlx::query!(
            "SELECT * FROM userpermissions WHERE permission = ? AND uid = ? AND gid = ?",
            permission,
            uid,
            gid
        )
        .fetch_optional(db)
        .await
        .ctx(str!(
            "Failed to check if UID {uid} has permission '{permission}' on GID {gid}",
        ))?;

        Ok(res.is_some())
    }

    /// Checks if `user` has been granted `permission` in any group
    ///
    /// This function checks if the permission is granted on **any**
    /// group in the Velocity system
    ///
    /// # Arguments
    /// * `db` - The database connection to execute the query on
    /// * `permission` - The permission to check for
    /// * `uid` - The user id to check the permissions of
    pub async fn is_granted_somewhere_raw(
        db: &SqlitePool,
        permission: &str,
        uid: u32,
    ) -> VResult<bool> {
        let res = sqlx::query!(
            "SELECT * FROM userpermissions WHERE permission = ? AND uid = ?",
            permission,
            uid,
        )
        .fetch_optional(db)
        .await
        .ctx(str!(
            "Failed to check if UID {uid} has permission '{permission}'",
        ))?;

        Ok(res.is_some())
    }
}

impl Permission {
    /// Ensures all the default permissions Velocity expects
    /// do exist in the database
    /// # Arguments
    /// * `db` - The database connection to ensure the permissions in
    pub async fn ensure_default_permissions(
        db: &SqlitePool,
        u_root: &User,
        g_root: &Group,
    ) -> VResult<()> {
        Permission::ensure(db, Entitlement::UserCreate.str())
            .await?
            .ensure_granted(db, u_root, g_root)
            .await?;

        Permission::ensure(db, Entitlement::UserRemove.str())
            .await?
            .ensure_granted(db, u_root, g_root)
            .await?;

        Permission::ensure(db, Entitlement::UserList.str())
            .await?
            .ensure_granted(db, u_root, g_root)
            .await?;

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
