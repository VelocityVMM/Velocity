//! The error handling subsystem of Velocity
//!
//! # Returning errors
//! Velocity's convention for returning errors depends on
//! whether the error is foreign or of type  [`VError`].
//!
//! ### Returning a foreign error
//! Errors that aren't already of type [`VError`] must be
//! enriched with context using the `.ctx(|| ...)` syntax.
//!
//! This ensures each and every error has at least some context
//! to it.
//!
//! ### Returning a [`VError`]
//! If a called function already returns [`VError`], adding context
//! to it is optional. If there is the need for context, it may
//! be supplied from the outside to reduce repetition.

use std::{collections::LinkedList, fmt::Display};

mod error_type;
pub use error_type::*;

/// A error to be passed around the Velocity program
#[derive(Debug)]
pub struct VError {
    /// The context of the error
    pub context: LinkedList<String>,
    /// The enclosed error
    pub error: VErrorType,
}

impl VError {
    /// Creates a new error with no context
    /// # Arguments
    /// * `error` - The error to enclose
    pub fn new(error: VErrorType) -> Self {
        Self {
            error,
            context: LinkedList::new(),
        }
    }

    /// Creates a new error with a context attached to it
    /// # Arguments
    /// * `error` - The error to enclose
    /// * `context` - The message to use as an initial context
    pub fn new_ctx<S: ToString>(error: VErrorType, context: S) -> Self {
        Self {
            error,
            context: {
                let mut l = LinkedList::new();
                l.push_back(context.to_string());
                l
            },
        }
    }
}

/// Trait for enriching errors with context
pub trait VErrorExt<T> {
    /// Adds context to an error. This function takes a trait, so strings do only get constructed when needed
    /// # Arguments
    /// * `context` - A closure that returns the context message
    fn ctx<S: ToString, F: Fn() -> S>(self, context: F) -> Result<T, VError>;
}

/// Utility macro that shortens `|| format!(...)` for use in `.ctx()`
#[macro_export]
macro_rules! str {
    ($($arg:tt)*) => {{
        || format!($($arg)*)
    }};
}

/// Trait for marking incoming errors
pub trait VErrorIn: Into<VErrorType> {}

/// A result that returns a [`VError`]
pub type VResult<T, E = VError> = core::result::Result<T, E>;

impl<T> VErrorExt<T> for Result<T, VError> {
    fn ctx<S: ToString, F: Fn() -> S>(self, context: F) -> Result<T, VError> {
        match self {
            Ok(v) => Ok(v),
            Err(mut e) => {
                e.context.push_front(context().to_string());
                Err(e)
            }
        }
    }
}

impl<T, U: VErrorIn> VErrorExt<T> for Result<T, U>
where
    T: Sized,
{
    fn ctx<S: ToString, F: Fn() -> S>(self, context: F) -> Result<T, VError> {
        match self {
            Ok(v) => Ok(v),
            Err(e) => Err(VError::new_ctx(e.into(), context())),
        }
    }
}

impl<T, U: VErrorIn> VErrorExt<T> for U
where
    T: Sized,
{
    fn ctx<S: ToString, F: Fn() -> S>(self, context: F) -> Result<T, VError> {
        Err(VError::new_ctx(self.into(), context()))
    }
}

impl Display for VError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Error: {} while", self.error)?;
        for (i, context) in self.context.iter().enumerate() {
            write!(f, "\n{}-- {}:", "  ".repeat(i + 1), context)?
        }
        write!(
            f,
            "\n{}-- {}",
            "  ".repeat(self.context.len() + 1),
            self.error
        )
    }
}
