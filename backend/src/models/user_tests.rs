use crate::{app::AppConfig, create_app};

pub async fn user_test(
    pool: &r2d2::Pool<diesel::r2d2::ConnectionManager<diesel::SqliteConnection>>,
    app_config: AppConfig,
) {
    use crate::{do_test, do_test_extract_id};
    use actix_web::{
        http::{Method, StatusCode},
        test,
    };

    let mut app = test::init_service(create_app!(pool, app_config)).await;

    // Check that using the wrong token gives an unauthorized error
    let req = test::TestRequest::with_uri("/api/admin/users")
        .method(Method::GET)
        .insert_header(("Authorization", "Bearer 0102"))
        .to_request();
    use actix_web::dev::Service;
    let resp = app.call(req).await;
    assert!(resp.is_err());
    assert!(resp.err().unwrap().to_string() == "Wrong token!");

    // Delete all the users
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/admin/users")
        .to_request();
    test::call_service(&mut app, req).await;

    // Create a user with an empty password
    do_test!(
        app,
        "",
        Method::POST,
        "/api/common/users",
        r#"{"name":"  Test name  ","password":""}"#,
        StatusCode::NOT_ACCEPTABLE,
        "password cannot be empty"
    );

    // Create a user
    let id = do_test_extract_id!(
        app,
        "",
        Method::POST,
        "/api/common/users",
        r#"{"name":"  Test name  ","password":"    Test password       "}"#,
        StatusCode::CREATED,
        r#"{"id":"#
    );

    // Get a user
    do_test!(
        app,
        "",
        Method::GET,
        &format!("/api/common/users/{}", id),
        "",
        StatusCode::OK,
        format!(r#"{{"id":{id},"name":"Test name","current_step":1}}"#)
    );

    // Get a non existing user
    do_test!(
        app,
        "",
        Method::GET,
        &format!("/api/common/users/{}", id + 1),
        "",
        StatusCode::NOT_FOUND,
        "Item not found"
    );

    // Patch the user
    do_test!(
        app,
        "0101",
        Method::PUT,
        &format!("/api/admin/users/{}", id),
        &format!(
            r#"{{"id":{id}, "name":"  Patched test name   ","password":"    Patched test password       ","current_step":2}}"#
        ),
        StatusCode::OK,
        format!(r#"{{"id":{id},"name":"Patched test name","current_step":2}}"#)
    );

    // Delete the user
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/admin/users/{}", id),
        "",
        StatusCode::OK,
        format!("Deleted object with id: {}", id)
    );

    // Delete a non existing user
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/admin/users/{}", id + 1),
        "",
        StatusCode::NOT_FOUND,
        "Item not found"
    );

    // Delete all the users
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/admin/users")
        .to_request();
    test::call_service(&mut app, req).await;

    // Create two users and get them all
    let id1 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/common/users",
        r#"{"name":"01_name","password":"01_password"}"#,
        StatusCode::CREATED,
        r#"{"id""#
    );
    let id2 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/common/users",
        r#"{"name":"02_name","password":"02_password"}"#,
        StatusCode::CREATED,
        r#"{"id""#
    );
    do_test!(
        app,
        "0101",
        Method::GET,
        "/api/admin/users",
        "",
        StatusCode::OK,
        format!(
            r#"[{{"id":{id1},"name":"01_name","current_step":1}},{{"id":{id2},"name":"02_name","current_step":1}}]"#
        )
    );

    // Delete all the users
    do_test!(
        app,
        "0101",
        Method::DELETE,
        "/api/admin/users",
        "",
        StatusCode::OK,
        "Deleted all objects"
    );
}
