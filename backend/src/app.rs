#[macro_export]
macro_rules! create_app {
    ($pool:expr, $app_data:expr) => {{
        use crate::models::{step, user};
        use actix_cors::Cors;
        use actix_web::{error, middleware, web, web::Data, App, HttpResponse};

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
            .app_data(Data::clone($app_data))
            .wrap(Cors::permissive())
            .wrap(middleware::Logger::default())
            .service(
                web::scope("/api/users")
                    .service(user::advance)
                    .service(user::current_step)
                    .service(user::read)
                    .service(user::create)
                    .service(user::read_all)
                    .service(user::update)
                    .service(user::delete_all)
                    .service(user::delete),
            )
            .service(
                web::scope("/api/steps")
                    .service(step::read)
                    .service(step::retrieve_image)
                    .service(step::retrieve_media)
                    .service(step::check_media)
                    .service(step::read_all)
                    .service(step::create)
                    .service(step::update)
                    .service(step::delete_all)
                    .service(step::delete)
                    .service(step::upload_image)
                    .service(step::delete_image)
                    .service(step::upload_media)
                    .service(step::delete_media),
            )
            .service(actix_files::Files::new("/", "./web").index_file("index.html"))
    }};
}
