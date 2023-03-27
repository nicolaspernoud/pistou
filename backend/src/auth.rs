use actix_web::{http::header::HeaderValue, FromRequest, HttpRequest};

use std::future::{ready, Ready};

use crate::errors::ServerError;

pub struct AppConfig {
    pub bearer_token: String,
    pub location_check: bool,
}

impl AppConfig {
    pub fn new(token: String, location_check: bool) -> Self {
        AppConfig {
            bearer_token: token,
            location_check: location_check,
        }
    }
}

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
mod bearer_tests {
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

#[cfg(test)]
mod extractor_tests {
    use actix_web::web::{Bytes, Data};
    use actix_web::{
        get,
        http::{self},
        test, App, HttpResponse,
    };

    use crate::auth::AppConfig;

    use super::Authenticated;

    #[get("/")]
    pub async fn read(_: Authenticated) -> HttpResponse {
        HttpResponse::Ok().body("RESTRICTED TO AUTHENTICATED USERS")
    }

    #[actix_web::test]
    async fn test_no_header() {
        let app = test::init_service(
            App::new()
                .app_data(Data::new(AppConfig::new("0101".to_string(), true)))
                .service(read),
        )
        .await;

        // No header
        let req = test::TestRequest::with_uri("/").to_request();
        let res = test::call_service(&app, req).await;
        assert_eq!(res.status(), http::StatusCode::UNAUTHORIZED);
        let body = test::read_body(res).await;
        assert_eq!(body, Bytes::from_static(b"no authorization header"));
    }

    #[actix_web::test]
    async fn test_empty_header() {
        let app = test::init_service(
            App::new()
                .app_data(Data::new(AppConfig::new("0101".to_string(), true)))
                .service(read),
        )
        .await;

        // Empty header
        let req = test::TestRequest::with_uri("/")
            .insert_header(("Authorization", ""))
            .to_request();
        let res = test::call_service(&app, req).await;
        assert_eq!(res.status(), http::StatusCode::UNAUTHORIZED);
        let body = test::read_body(res).await;
        assert_eq!(
            body,
            Bytes::from_static(b"authorization header is too short")
        );
    }

    #[actix_web::test]
    async fn test_empty_token() {
        let app = test::init_service(
            App::new()
                .app_data(Data::new(AppConfig::new("0101".to_string(), true)))
                .service(read),
        )
        .await;

        // Empty token
        let req = test::TestRequest::with_uri("/")
            .insert_header(("Authorization", "Bearer "))
            .to_request();
        let res = test::call_service(&app, req).await;
        assert_eq!(res.status(), http::StatusCode::UNAUTHORIZED);
        let body = test::read_body(res).await;
        assert_eq!(
            body,
            Bytes::from_static(b"authorization header is too short")
        );
    }

    #[actix_web::test]
    async fn test_wrong_token() {
        let app = test::init_service(
            App::new()
                .app_data(Data::new(AppConfig::new("0101".to_string(), true)))
                .service(read),
        )
        .await;

        // Wrong token
        let req = test::TestRequest::with_uri("/")
            .insert_header(("Authorization", "Bearer 0202"))
            .to_request();
        let res = test::call_service(&app, req).await;
        assert_eq!(res.status(), http::StatusCode::FORBIDDEN);
        let body = test::read_body(res).await;
        assert_eq!(body, Bytes::from_static(b"wrong token"));
    }

    #[actix_web::test]
    async fn test_good_token() {
        let app = test::init_service(
            App::new()
                .app_data(Data::new(AppConfig::new("0101".to_string(), true)))
                .service(read),
        )
        .await;

        // Good token
        let req = test::TestRequest::with_uri("/")
            .insert_header(("Authorization", "Bearer 0101"))
            .to_request();
        let res = test::call_service(&app, req).await;
        assert_eq!(res.status(), http::StatusCode::OK);
        let body = test::read_body(res).await;
        assert_eq!(
            body,
            Bytes::from_static(b"RESTRICTED TO AUTHENTICATED USERS")
        );
    }
}
