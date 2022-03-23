use actix_web::error::{self};
use actix_web::{dev::ServiceRequest, Error};
use actix_web_httpauth::extractors::bearer::BearerAuth;

#[derive(Clone)]
pub struct AppConfig {
    pub bearer_token: String,
}

impl AppConfig {
    pub fn new(token: String) -> Self {
        AppConfig {
            bearer_token: token,
        }
    }
}

pub async fn validator(
    req: ServiceRequest,
    credentials: BearerAuth,
) -> Result<ServiceRequest, Error> {
    let app_config = req
        .app_data::<actix_web::web::Data<AppConfig>>()
        .expect("Could not get token configuration");
    if app_config.bearer_token == credentials.token() {
        Ok(req)
    } else {
        Err(error::ErrorUnauthorized("Wrong token!"))
    }
}

#[macro_export]
macro_rules! create_app {
    ($pool:expr, $app_config:expr) => {{
        use crate::models::{step, user};
        use actix_cors::Cors;
        use actix_web::{error, middleware, web, web::Data, App, HttpResponse};
        use actix_web_httpauth::middleware::HttpAuthentication;

        App::new()
            .app_data(Data::new($pool.clone()))
            .app_data(
                web::JsonConfig::default()
                    .limit(4096)
                    .error_handler(|err, _req| {
                        error::InternalError::from_response(err, HttpResponse::Conflict().finish())
                            .into()
                    }),
            )
            .app_data(web::Data::new($app_config))
            .wrap(Cors::permissive())
            .wrap(middleware::Logger::default())
            .service(
                web::scope("/api/common/users")
                    .service(user::advance)
                    .service(user::current_step)
                    .service(user::read)
                    .service(user::create),
            )
            .service(
                web::scope("/api/admin/users")
                    .service(user::read_all)
                    .service(user::update)
                    .service(user::delete_all)
                    .service(user::delete)
                    .wrap(HttpAuthentication::bearer(crate::app::validator)),
            )
            .service(
                web::scope("/api/common/steps")
                    .service(step::read)
                    .service(step::retrieve_image)
                    .service(step::retrieve_sound),
            )
            .service(
                web::scope("/api/admin/steps")
                    .service(step::read_all)
                    .service(step::create)
                    .service(step::update)
                    .service(step::delete_all)
                    .service(step::delete)
                    .service(step::upload_image)
                    .service(step::delete_image)
                    .service(step::upload_sound)
                    .service(step::delete_sound)
                    .wrap(HttpAuthentication::bearer(crate::app::validator)),
            )
            .service(actix_files::Files::new("/", "./web").index_file("index.html"))
    }};
}
