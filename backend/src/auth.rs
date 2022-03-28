use actix_web::{http::header::HeaderValue, FromRequest, HttpRequest};

use std::future::{ready, Ready};

use crate::{app::AppConfig, errors::ServerError};

pub struct Authenticated;

impl FromRequest for Authenticated {
    fn from_request(req: &HttpRequest, _payload: &mut actix_web::dev::Payload) -> Self::Future {
        let app_config = req
            .app_data::<actix_web::web::Data<AppConfig>>()
            .expect("Could not get token configuration");

        if let Some(token) = req.headers().get("Authorization") {
            let bearer = match Bearer::parse(token) {
                Ok(b) => b,
                Err(e) => {
                    return ready(Err(e));
                }
            };

            let result = if app_config.bearer_token == bearer.token {
                Ok(Authenticated)
            } else {
                Err(ServerError::Forbidden("wrong token".to_string()))
            };
            ready(result)
        } else {
            ready(Err(ServerError::Unauthorized(
                "no authorization header".to_string(),
            )))
        }
    }

    fn extract(req: &HttpRequest) -> Self::Future {
        Self::from_request(req, &mut actix_web::dev::Payload::None)
    }

    type Error = ServerError;

    type Future = Ready<Result<Self, Self::Error>>;
}

pub struct Bearer {
    token: String,
}

impl Bearer {
    fn parse(header: &HeaderValue) -> Result<Self, ServerError> {
        // "Bearer *" length
        if header.len() < 8 {
            return Err(ServerError::Unauthorized(
                "authorization header is too short".to_string(),
            ));
        }

        let header = header.to_str().unwrap_or_default();

        let mut parts = header.splitn(2, ' ');
        match parts.next() {
            Some(scheme) if scheme == "Bearer" => (),
            _ => return Err(ServerError::Unauthorized("missing scheme".to_string())),
        }

        let token = parts
            .next()
            .ok_or(ServerError::Unauthorized("invalid token".to_string()))?;

        Ok(Bearer {
            token: token.to_string().into(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_header() {
        let value = HeaderValue::from_static("Bearer mF_9.B5f-4.1JqM");
        let scheme = Bearer::parse(&value);

        assert!(scheme.is_ok());
        let scheme = scheme.unwrap();
        assert_eq!(scheme.token, "mF_9.B5f-4.1JqM");
    }

    #[test]
    fn test_empty_header() {
        let value = HeaderValue::from_static("");
        let scheme = Bearer::parse(&value);

        assert!(scheme.is_err());
    }

    #[test]
    fn test_wrong_scheme() {
        let value = HeaderValue::from_static("OAuthToken foo");
        let scheme = Bearer::parse(&value);

        assert!(scheme.is_err());
    }

    #[test]
    fn test_missing_token() {
        let value = HeaderValue::from_static("Bearer ");
        let scheme = Bearer::parse(&value);

        assert!(scheme.is_err());
    }
}
