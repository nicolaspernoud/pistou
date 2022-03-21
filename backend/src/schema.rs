table! {
    steps (id) {
        id -> Integer,
        rank -> Integer,
        latitude -> Double,
        longitude -> Double,
        location_hint -> Text,
        question -> Text,
        answer -> Text,
        media -> Text,
        is_end -> Bool,
    }
}

table! {
    users (id) {
        id -> Integer,
        name -> Text,
        password -> Text,
        current_step -> Integer,
    }
}

allow_tables_to_appear_in_same_query!(
    steps,
    users,
);
