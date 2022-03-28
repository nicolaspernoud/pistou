use crate::{app::AppConfig, create_app};

pub async fn step_test(
    pool: &r2d2::Pool<diesel::r2d2::ConnectionManager<diesel::SqliteConnection>>,
    app_config: AppConfig,
) {
    use crate::{do_test, do_test_extract_id};
    use actix_web::{
        http::{Method, StatusCode},
        test,
    };

    let mut app = test::init_service(create_app!(pool, app_config)).await;

    // Delete all the steps
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/steps")
        .to_request();
    test::call_service(&mut app, req).await;

    // Create a step
    let id = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/steps",
        r#"{"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"  go there  ","question":" what is the color of the sky?  ","answer":"  blue  ","media":"  1.jpg  "}"#,
        StatusCode::CREATED,
        "{\"id\""
    );

    // Get a step
    do_test!(
        app,
        "0101",
        Method::GET,
        &format!("/api/steps/{}", id),
        "",
        StatusCode::OK,
        format!(
            r#"{{"id":{id},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}}"#
        )
    );

    // Get a non existing step
    do_test!(
        app,
        "0101",
        Method::GET,
        &format!("/api/steps/{}", id + 1),
        "",
        StatusCode::NOT_FOUND,
        "Item not found"
    );

    // Patch the step
    do_test!(
        app,
        "0101",
        Method::PUT,
        &format!("/api/steps/{}", id),
        &format!(
            r#"{{"id":{id},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the grass?","answer":"green","media":"1.jpg","is_end":false}}"#
        ),
        StatusCode::OK,
        format!(
            r#"{{"id":{id},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the grass?","answer":"green","media":"1.jpg","is_end":false}}"#
        )
    );

    // Delete the step
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/steps/{}", id),
        "",
        StatusCode::OK,
        format!("Deleted object with id: {}", id)
    );

    // Delete a non existing step
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/steps/{}", id + 1),
        "",
        StatusCode::NOT_FOUND,
        "Item not found"
    );

    // Delete all the steps
    let req = test::TestRequest::delete()
        .insert_header(("Authorization", "Bearer 0101"))
        .uri("/api/steps")
        .to_request();
    test::call_service(&mut app, req).await;

    // Create two steps and get them all
    let id1 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/steps",
        r#"{"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}"#,
        StatusCode::CREATED,
        "{\"id\""
    );
    let id2 = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/steps",
        r#"{"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"what is the color of the grass?","answer":"green","media":"2.jpg","is_end":false}"#,
        StatusCode::CREATED,
        "{\"id\""
    );
    do_test!(
        app,
        "0101",
        Method::GET,
        "/api/steps",
        "",
        StatusCode::OK,
        format!(
            r#"[{{"id":{id1},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}},{{"id":{id2},"rank":2,"latitude":45.16667,"longitude":5.71667,"location_hint":"go there after","question":"what is the color of the grass?","answer":"green","media":"2.jpg","is_end":false}}]"#
        )
    );

    // Create another step with a incorrect rank and test that it has been reranked
    let id3 = id2 + 1;
    do_test!(
        app,
        "0101",
        Method::POST,
        "/api/steps",
        r#"{"rank":4,"latitude":45.366669,"longitude":5.58333,"location_hint":"go there after","question":"what is the color of the sun?","answer":"yellow","media":"3.jpg","is_end":false}"#,
        StatusCode::CREATED,
        format!(r#"{{"id":{id3},"rank":3,"latitude":45.366669,"longitude":5.58333"#)
    );

    // Delete the second step
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/steps/{}", id2),
        "",
        StatusCode::OK,
        format!("Deleted object with id: {}", id2)
    );

    // Check that the steps have been reranked
    do_test!(
        app,
        "0101",
        Method::GET,
        "/api/steps",
        "",
        StatusCode::OK,
        format!(
            r#"[{{"id":{id1},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the sky?","answer":"blue","media":"1.jpg","is_end":false}},{{"id":{id3},"rank":2,"latitude":45.366669,"longitude":5.58333,"location_hint":"go there after","question":"what is the color of the sun?","answer":"yellow","media":"3.jpg","is_end":false}}]"#
        )
    );

    // Alter the first steps and check that it has been reranked
    do_test!(
        app,
        "0101",
        Method::PUT,
        &format!("/api/steps/{}", id1),
        &format!(
            r#"{{"id":{id1},"rank":10,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the city?","answer":"grey","media":"1.jpg","is_end":false}}"#
        ),
        StatusCode::OK,
        format!(
            r#"{{"id":{id1},"rank":2,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the city?","answer":"grey","media":"1.jpg","is_end":false}}"#
        )
    );

    // Check that the steps have been reranked
    do_test!(
        app,
        "0101",
        Method::GET,
        "/api/steps",
        "",
        StatusCode::OK,
        format!(
            r#"[{{"id":{id1},"rank":2,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the city?","answer":"grey","media":"1.jpg","is_end":false}},{{"id":{id3},"rank":1,"latitude":45.366669,"longitude":5.58333,"location_hint":"go there after","question":"what is the color of the sun?","answer":"yellow","media":"3.jpg","is_end":false}}]"#
        )
    );

    // Alter the id1 step and make sure that is has been reranked to first
    do_test!(
        app,
        "0101",
        Method::PUT,
        &format!("/api/steps/{}", id1),
        &format!(
            r#"{{"id":{id1},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the city?","answer":"grey","media":"1.jpg","is_end":false}}"#
        ),
        StatusCode::OK,
        format!(
            r#"{{"id":{id1},"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"go there","question":"what is the color of the city?","answer":"grey","media":"1.jpg","is_end":false}}"#
        )
    );

    // Alter the id3 step and make sure that is has been reranked to first
    do_test!(
        app,
        "0101",
        Method::PUT,
        &format!("/api/steps/{}", id3),
        &format!(
            r#"{{"id":{id3},"rank":1,"latitude":45.366669,"longitude":5.58333,"location_hint":"go there after","question":"what is the color of the sun?","answer":"yellow","media":"3.jpg","is_end":false}}"#
        ),
        StatusCode::OK,
        format!(
            r#"{{"id":{id3},"rank":1,"latitude":45.366669,"longitude":5.58333,"location_hint":"go there after","question":"what is the color of the sun?","answer":"yellow","media":"3.jpg","is_end":false}}"#
        )
    );

    // Delete all the steps
    do_test!(
        app,
        "0101",
        Method::DELETE,
        "/api/steps",
        "",
        StatusCode::OK,
        "Deleted all objects"
    );

    //////////////////
    // IMAGES TESTS //
    //////////////////

    // Create a step
    let id = do_test_extract_id!(
        app,
        "0101",
        Method::POST,
        "/api/steps",
        r#"{"rank":1,"latitude":45.74846,"longitude":4.84671,"location_hint":"  go there  ","question":" what is the color of the sky?  ","answer":"  blue  ","media":"  1.jpg  "}"#,
        StatusCode::CREATED,
        "{\"id\""
    );

    // Upload a image for this step
    let img_body = std::fs::read("test_img.jpg").unwrap();
    let req = test::TestRequest::with_uri(format!("/api/steps/images/{}", id).as_str())
        .method(Method::POST)
        .insert_header(("Authorization", "Bearer 0101"))
        .set_payload(img_body.clone())
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::OK);

    // Retrieve the image
    let req = test::TestRequest::with_uri(format!("/api/steps/images/{}", id).as_str())
        .method(Method::GET)
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::OK);
    let body = test::read_body(resp).await;
    assert_eq!(body, img_body);

    // Upload a sound for this step (we use the same image file, as we only want to test the upload, retrieving, and deletion)
    let img_body = std::fs::read("test_img.jpg").unwrap();
    let req = test::TestRequest::with_uri(format!("/api/steps/sounds/{}", id).as_str())
        .method(Method::POST)
        .insert_header(("Authorization", "Bearer 0101"))
        .set_payload(img_body.clone())
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::OK);

    // Retrieve the sound
    let req = test::TestRequest::with_uri(format!("/api/steps/sounds/{}", id).as_str())
        .method(Method::GET)
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::OK);
    let body = test::read_body(resp).await;
    assert_eq!(body, img_body);

    // Delete the step
    do_test!(
        app,
        "0101",
        Method::DELETE,
        &format!("/api/steps/{}", id),
        "",
        StatusCode::OK,
        format!("Deleted object with id: {}", id)
    );

    // Check that the image is gone too
    let req = test::TestRequest::with_uri(format!("/api/steps/images/{}", id).as_str())
        .method(Method::GET)
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);

    // Check that the sound is gone too
    let req = test::TestRequest::with_uri(format!("/api/steps/sounds/{}", id).as_str())
        .method(Method::GET)
        .to_request();
    let resp = test::call_service(&mut app, req).await;
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}
