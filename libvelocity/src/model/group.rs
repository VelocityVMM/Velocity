use std::fmt::Display;

use sqlx::SqlitePool;

use crate::{
    error::{VErrorExt, VResult},
    str,
};

/// A group in the Velocity system
#[derive(Debug, Clone)]
pub struct Group {
    /// The group id is the primary key, so it is guarded
    gid: u32,
    /// The group id of the parent group
    parent_gid: Option<u32>,
    /// The groupname of the group
    pub groupname: String,
}

/// Errors that can occur when working with groups
#[derive(Debug)]
pub enum GroupError {
    /// A group id (gid) has not been found
    GroupIDNotFound(u32),
    /// A groupname has not been found
    GroupnameNotFound(String),
}

impl Group {
    /// Creates a new in-memory group without a backing database entry
    ///
    /// # Warning
    /// The created group does not have any backing database entry -
    /// any actions that require a database connection to work may error
    /// with inexplicable errors
    ///
    /// # Arguments
    /// * `gid` - The group id to assign
    /// * `parent_gid` - The parent group id to assign
    /// * `groupname` - The groupname to assign
    fn new(gid: u32, parent_gid: Option<u32>, groupname: String) -> Self {
        Self {
            gid,
            parent_gid,
            groupname,
        }
    }

    /// Returns the group id of the group
    pub fn gid(&self) -> u32 {
        self.gid
    }

    /// Returns the group id of the parent group
    pub fn parent_gid(&self) -> Option<u32> {
        self.parent_gid
    }

    /// Returns the group id of the parent group or `0` for the `root` group
    pub fn lossy_parent_gid(&self) -> u32 {
        self.parent_gid.unwrap_or(0)
    }

    /// Creates a new group in the supplied database
    ///
    /// # Warning
    /// This will fail if a group with the same name and parent group id
    /// does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database to create the new group in
    /// * `groupname` - The unique groupname to use for the new group
    /// * `parent` - The parent group the new group is part of, `None` for a root group
    pub async fn create(
        db: &SqlitePool,
        groupname: &str,
        parent: Option<&Group>,
    ) -> VResult<Group> {
        let parent_gid = match parent {
            None => 0,
            Some(p) => p.gid(),
        };

        sqlx::query!(
            "INSERT INTO groups (parent_gid, groupname) VALUES (?, ?)",
            parent_gid,
            groupname
        )
        .execute(db)
        .await
        .ctx(str!("Failed to insert group '{groupname}'"))?;

        Self::select_groupname(db, groupname).await
    }

    /// Creates a new group in the supplied database with a specific group id
    ///
    /// # Warning
    /// This will fail if a group with the same name and parent group id
    /// does already exist within the database
    ///
    /// # Arguments
    /// * `db` - The database to create the new group in
    /// * `gid` - The group id to assign to the newly created group
    /// * `groupname` - The unique groupname to use for the new group
    /// * `parent` - The parent for the newly created group, `None` for a root group
    pub async fn create_with_gid(
        db: &SqlitePool,
        gid: u32,
        groupname: &str,
        parent: Option<&Group>,
    ) -> VResult<Group> {
        let parent_gid = match parent {
            None => 0,
            Some(p) => p.gid(),
        };

        sqlx::query!(
            "INSERT INTO groups (gid, parent_gid, groupname) VALUES (?, ?, ?)",
            gid,
            parent_gid,
            groupname
        )
        .execute(db)
        .await
        .ctx(str!("Failed to insert group '{groupname}' ({gid})"))?;

        Self::select_groupname(db, groupname).await
    }

    /// Tries to select a group by `groupname`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `groupname` - The groupname of the group to select
    ///
    /// # Returns
    /// The group or `None` if it does not exist
    pub async fn try_select_groupname(db: &SqlitePool, groupname: &str) -> VResult<Option<Self>> {
        let res = sqlx::query!(
            "SELECT gid, parent_gid, groupname FROM groups WHERE groupname = ?",
            groupname,
        )
        .fetch_optional(db)
        .await
        .ctx(str!("Failed to select group '{groupname}'"))?;

        let res = match res {
            None => return Ok(None),
            Some(res) => res,
        };

        Ok(Some(Self::new(
            res.gid as u32,
            res.parent_gid.map(|x| x as u32),
            res.groupname,
        )))
    }

    /// Selects a group by `groupname`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `groupname` - The groupname of the group to select
    pub async fn select_groupname(db: &SqlitePool, groupname: &str) -> VResult<Self> {
        let group = Self::try_select_groupname(db, groupname).await?;

        match group {
            Some(group) => Ok(group),
            None => GroupError::GroupnameNotFound(groupname.to_owned())
                .ctx(str!("Selecting group by groupname: '{groupname}'")),
        }
    }

    /// Tries to select a group by `gid`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `gid` - The group id of the group to select
    ///
    /// # Returns
    /// The group or `None` if it doesn't exist
    pub async fn try_select_gid(db: &SqlitePool, gid: u32) -> VResult<Option<Self>> {
        let res = sqlx::query!(
            "SELECT gid, parent_gid, groupname FROM groups WHERE gid = ?",
            gid
        )
        .fetch_optional(db)
        .await
        .ctx(str!("Failed to select group {gid}"))?;

        let res = match res {
            None => return Ok(None),
            Some(res) => res,
        };

        Ok(Some(Self::new(
            res.gid as u32,
            res.parent_gid.map(|x| x as u32),
            res.groupname,
        )))
    }

    /// Selects a group by `gid`
    ///
    /// # Arguments
    /// * `db` - The database to select from
    /// * `gid` - The group id of the group to select
    pub async fn select_gid(db: &SqlitePool, gid: u32) -> VResult<Self> {
        let group = Self::try_select_gid(db, gid).await?;

        match group {
            Some(group) => Ok(group),
            None => GroupError::GroupIDNotFound(gid).ctx(str!("Selecting group by gid: {gid}")),
        }
    }

    /// Applies the changes from `self` to the database entry with the same `gid`
    ///
    /// # Arguments
    /// * `db` - The database to apply the new values to
    pub async fn apply(&self, db: &SqlitePool) -> VResult<()> {
        sqlx::query!(
            "UPDATE groups SET groupname = ?, parent_gid = ? WHERE gid = ?",
            self.groupname,
            self.parent_gid,
            self.gid
        )
        .execute(db)
        .await
        .ctx(str!("Failed to update group"))?;

        Ok(())
    }
}

impl Display for Group {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} ({})", self.groupname, self.gid)
    }
}

impl Display for GroupError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::GroupIDNotFound(gid) => write!(f, "Group ID {gid} not found"),
            Self::GroupnameNotFound(groupname) => write!(f, "Groupname '{groupname}' not found"),
        }
    }
}
