CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    name VARCHAR NOT NULL,
    password VARCHAR NOT NULL,
    current_step INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE steps (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    rank INTEGER NOT NULL,
    latitude DOUBLE NOT NULL,
    longitude DOUBLE NOT NULL,
    location_hint VARCHAR NOT NULL,
    question VARCHAR NOT NULL,
    shake_message VARCHAR,
    answer VARCHAR NOT NULL,
    is_end BOOLEAN NOT NULL
);

INSERT INTO
    steps (
        rank,
        latitude,
        longitude,
        location_hint,
        question,
        answer,
        is_end
    )
VALUES
    (
        1,
        45.74846,
        4.84671,
        "Go there",
        "What is the color of the sky?",
        "Blue",
        false
    );