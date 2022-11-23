// @generated automatically by Diesel CLI.

diesel::table! {
    steps (id) {
        id -> Integer,
        rank -> Integer,
        latitude -> Double,
        longitude -> Double,
        location_hint -> Text,
        question -> Text,
        shake_message -> Nullable<Text>,
        answer -> Text,
        is_end -> Bool,
    }
}

diesel::table! {
    users (id) {
        id -> Integer,
        name -> Text,
        password -> Text,
        current_step -> Integer,
    }
}

diesel::allow_tables_to_appear_in_same_query!(
    steps,
    users,
);
