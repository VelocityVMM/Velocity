//! Macros for use with the velocity project

extern crate proc_macro;
extern crate proc_macro2;

use proc_macro::TokenStream;
use proc_macro2::Span;
use quote::{quote, quote_spanned};
use syn::{parse_macro_input, spanned::Spanned, Data, DeriveInput, Error, Fields, Meta};

/// A error in a derive macro
macro_rules! derive_error {
    ($string: tt) => {
        Error::new(Span::call_site(), $string)
            .to_compile_error()
            .into()
    };
}

/// A derive macro that implements the `IntoAPIError` trait for an enum
#[proc_macro_derive(IntoAPIError, attributes(expose))]
pub fn into_api_error(input: TokenStream) -> TokenStream {
    let input: DeriveInput = parse_macro_input!(input);

    let mut found = false;
    for x in input.attrs.clone() {
        if !x.path().is_ident("repr") {
            continue;
        }

        match x.meta {
            Meta::List(list) => {
                if &list.tokens.to_string() == "u16" {
                    found = true;
                }
            }
            _ => {}
        }
    }

    if !found {
        return derive_error!("Need enum to use #[repr(u16)]");
    }

    let enum_ident = input.ident;
    match input.data.clone() {
        Data::Enum(data) => {
            let mut fields = Vec::new();

            for variant in data.variants {
                let fields_in_variant = match &variant.fields {
                    Fields::Unnamed(_) => quote_spanned! {variant.span()=> (..) },
                    Fields::Unit => quote_spanned! { variant.span()=> },
                    Fields::Named(_) => quote_spanned! {variant.span()=> {..} },
                };

                let variant_ident = variant.ident;
                let expose: Vec<String> = variant
                    .attrs
                    .iter()
                    .map_while(|x| match &x.meta {
                        Meta::List(list) => {
                            if list.path.is_ident("expose") {
                                Some(list.tokens.to_string())
                            } else {
                                None
                            }
                        }
                        _ => None,
                    })
                    .collect();

                if expose.len() > 0 {
                    let x: syn::Path = syn::parse_str(&expose[0]).unwrap();
                    fields.push(quote! {
                        #enum_ident::#variant_ident #fields_in_variant => #x,
                    });
                }
            }

            quote! {
                impl IntoAPIError for #enum_ident {
                    fn get_code(&self) -> u16 {
                        unsafe { *(self as *const Self as *const u16) }
                    }

                    fn get_status(&self) -> StatusCode {
                        match self {
                            #(#fields)*
                            _ => StatusCode::INTERNAL_SERVER_ERROR,
                        }
                    }
                }
            }
            .into()
        }
        _ => derive_error!("Can only implement IntoAPIError for enums"),
    }
}
