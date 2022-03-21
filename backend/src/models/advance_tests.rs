use crate::{app::AppConfig, create_app};

pub async fn advance_test(
    pool: &r2d2::Pool<diesel::r2d2::ConnectionManager<diesel::SqliteConnection>>,
    app_config: AppConfig,
) {
    use crate::{do_test, do_test_extract_id};
    use actix_web::{
        http::{Method, StatusCode},
        test,
    };

    let mut app = test::init_service(create_app!(pool, app_config)).await;

    // Delete all the users
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/admin/users")
        .to_request();
    test::call_service(&mut app, req).await;

    // Delete all the steps
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/admin/steps")
        .to_request();
    test::call_service(&mut app, req).await;

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

    // Create two steps and get them all
    let id1 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/admin/steps",
        r#"{"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}"#,
        StatusCode::CREATED,
        "{\"id\""
    );
    let id2 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/admin/steps",
        r#"{"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"quel est le plus grand parc de Lyon ?","answer":"Le Parc de la Tête d'Or","media":"2.jpg","is_end":false}"#,
        StatusCode::CREATED,
        "{\"id\""
    );

    // Get the current step
    do_test!(
        app,
        "0101",
        Method::GET,
        &format!("/api/common/users/{id}/current_step"),
        "",
        StatusCode::OK,
        format!(
            r#"{{"id":{id1},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}}"#
        )
    );

    // Try to advance step with the wrong password (must fail)
    do_test!(
        app,
        "0101",
        Method::POST,
        &format!("/api/common/users/{id}/advance"),
        r#"{"password":"Wrong test password","latitude":45.74846,"longitude":4.84671,"answer":"yellow"}"#,
        StatusCode::FORBIDDEN,
        r#"{"type":"WrongPassword"}"#
    );
    // Try to advance step with the right password, but the wrong position (must fail, and give a hint on how to reach the right position)
    do_test!(
        app,
        "0101",
        Method::POST,
        &format!("/api/common/users/{id}/advance"),
        r#"{"password":"Test password","latitude":45.16667,"longitude":5.71667,"answer":"yellow"}"#,
        StatusCode::NOT_ACCEPTABLE,
        r#"{"type":"WrongPlace","distance":93749.54"#
    );

    // Try to advance step with the right password, the right position, but the wrong answer (must fail)
    do_test!(
        app,
        "0101",
        Method::POST,
        &format!("/api/common/users/{id}/advance"),
        r#"{"password":"Test password","latitude":45.74846,"longitude":4.84671,"answer":"yellow"}"#,
        StatusCode::NOT_ACCEPTABLE,
        r#"{"type":"WrongAnswer"}"#
    );

    // Try to advance step with the right password, the right position, and the right answer (must pass)
    do_test!(
        app,
        "0101",
        Method::POST,
        &format!("/api/common/users/{id}/advance"),
        r#"{"password":"Test password","latitude":45.74846,"longitude":4.84671,"answer":"blue"}"#,
        StatusCode::OK,
        format!(
            r#"{{"type":"Success","id":{id2},"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"quel est le plus grand parc de Lyon ?","answer":"Le Parc de la Tête d'Or","media":"2.jpg","is_end":false}}"#
        )
    );

    // Get the current step
    do_test!(
        app,
        "0101",
        Method::GET,
        &format!("/api/common/users/{id}/current_step"),
        "",
        StatusCode::OK,
        format!(
            r#"{{"id":{id2},"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"quel est le plus grand parc de Lyon ?","answer":"Le Parc de la Tête d'Or","media":"2.jpg","is_end":false}}"#
        )
    );

    // Try to advance step with the right password, the right position, and a CLOSE answer (must pass, with 404 since there is no more steps)
    do_test!(
        app,
        "0101",
        Method::POST,
        &format!("/api/common/users/{id}/advance"),
        r#"{"password":"Test password","latitude":45.16667,"longitude":5.71667,"answer":"parc tete dor"}"#,
        StatusCode::NOT_FOUND,
        "Item not found"
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

    // Delete all the steps
    do_test!(
        app,
        "0101",
        Method::DELETE,
        "/api/admin/steps",
        "",
        StatusCode::OK,
        "Deleted all objects"
    );
}
