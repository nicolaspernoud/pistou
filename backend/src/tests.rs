#[cfg(test)]
mod tests {
    use actix_web::web::Data;

    use crate::{
        auth::AppConfig,
        models::{advance_tests::advance_test, step_tests::step_test, user_tests::user_test},
    };
    #[actix_rt::test]
    async fn test_models() {
        use diesel::r2d2::{self, ConnectionManager};
        use diesel::SqliteConnection;
        use diesel_migrations::{EmbeddedMigrations, MigrationHarness};
        std::env::set_var("RUST_LOG", "debug");
        env_logger::init();

        // set up database connection pool
        let manager = ConnectionManager::<SqliteConnection>::new("db/test_db.sqlite");
        let pool = r2d2::Pool::builder()
            .build(manager)
            .expect("Failed to create pool.");
        pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("db/migrations");
        pool.get()
            .expect("couldn't get db connection from pool")
            .run_pending_migrations(MIGRATIONS)
            .expect("couldn't run migrations");

        // Set up authorization token
        let app_config = AppConfig::new("0101".to_string(), true);
        let app_data = Data::new(app_config);

        user_test(&pool, &app_data).await;
        step_test(&pool, &app_data).await;
        advance_test(&pool, &app_data).await;
    }
}
