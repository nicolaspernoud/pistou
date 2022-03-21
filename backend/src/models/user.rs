use log::{debug, info};
use serde::{Deserialize, Serialize};

use crate::{
    crud_create, crud_delete, crud_delete_all, crud_read, crud_read_all, crud_use,
    errors::ServerError, models::step::Step, schema::users,
};

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2, PasswordHash, PasswordVerifier,
};

macro_rules! trim {
    () => {
        fn trim(&mut self) -> Result<&Self, ServerError> {
            self.name = self.name.trim().to_string();
            if self.password.is_empty() {
                return Err(ServerError::NotAcceptable(
                    "password cannot be empty".to_string(),
                ));
            }

            let salt = SaltString::generate(&mut OsRng);
            let argon2 = Argon2::default();
            // Hash password to PHC string ($argon2id$v=19$...)
            match argon2.hash_password(self.password.trim().as_bytes(), &salt) {
                Ok(password) => {
                    self.password = password.to_string();
                    Ok(self)
                }
                Err(_) => Err(ServerError::NotAcceptable(
                    "the provided password is not acceptable".to_string(),
                )),
            }
        }
    };
}

#[derive(
    Debug, Clone, Serialize, Deserialize, Queryable, Insertable, AsChangeset, Identifiable,
)]
#[table_name = "users"]
pub struct User {
    pub id: i32,
    pub name: String,
    #[serde(skip_serializing)]
    pub password: String,
    pub current_step: i32,
}
impl User {
    trim!();
}

#[derive(Debug, Clone, Serialize, Deserialize, Insertable)]
#[table_name = "users"]
pub struct NewUser {
    pub name: String,
    pub password: String,
}
impl NewUser {
    trim!();
}

crud_use!();
crud_create!(NewUser, User, users,);
crud_read_all!(User, users);
crud_read!(User, users);

#[put("/{oid}")]
pub async fn update(
    pool: web::Data<DbPool>,
    mut o: web::Json<User>,
    oid: web::Path<i32>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    let put_o: Result<User, ServerError> = web::block(move || {
        use crate::schema::users::dsl::*;

        // Do not update password if the given password is empty
        let u = users.filter(id.eq(*oid)).first::<User>(&conn)?;
        if o.password.is_empty() {
            o.password = u.password;
            o.name = o.name.trim().to_string();
        } else {
            o.trim()?;
        }

        diesel::update(users)
            .filter(id.eq(*oid))
            .set(&*o)
            .execute(&conn)?;

        let u = users.filter(id.eq(*oid)).first::<User>(&conn)?;
        Ok(u)
    })
    .await?;

    Ok(HttpResponse::Ok().json(put_o?))
}

crud_delete!(User, users);
crud_delete_all!(User, users);

#[derive(Default, Debug, Clone, PartialEq, Deserialize)]
pub struct Answer {
    pub password: String,
    pub latitude: f64,
    pub longitude: f64,
    pub answer: String,
}

#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Message {
    WrongPassword,
    WrongPlace { distance: f64 },
    WrongAnswer,
    Success(Step),
}

// Advance step if all is ok
#[post("/{oid}/advance")]
pub async fn advance(
    pool: web::Data<DbPool>,
    oid: web::Path<i32>,
    answer: web::Json<Answer>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    let step = web::block(move || {
        use crate::schema::steps::dsl::rank;
        use crate::schema::steps::dsl::steps;
        use crate::schema::users::dsl::*;
        // Get the user with that id
        let u = users.find(*oid).first::<User>(&conn)?;

        // Check if the given password is correct
        let parsed_hash = PasswordHash::new(&u.password).map_err(|_| {
            ServerError::Forbidden(serde_json::to_string(&Message::WrongPassword).unwrap())
        })?;
        if !Argon2::default()
            .verify_password(answer.password.as_bytes(), &parsed_hash)
            .is_ok()
        {
            return Err(ServerError::Forbidden(
                serde_json::to_string(&Message::WrongPassword).unwrap(),
            ));
        }

        // Get the user's current step
        let s = steps.filter(rank.eq(u.current_step)).first::<Step>(&conn)?;

        // Check that the location is close enough
        let dist = get_dist(answer.latitude, answer.longitude, s.latitude, s.longitude);
        info!("Distance: {}", dist);
        if dist > 50.0 {
            return Err(ServerError::NotAcceptable(
                serde_json::to_string(&Message::WrongPlace { distance: dist }).unwrap(),
            ));
        }

        // Check that the given answer is correct
        let remove_accents = |x| match x {
            'é' => 'e',
            'ê' => 'e',
            'è' => 'e',
            'É' => 'E',
            'Ê' => 'E',
            'È' => 'E',
            c => c,
        };
        let good_answer: String = s
            .answer
            .chars()
            .map(remove_accents)
            .filter(|c| c.is_alphanumeric() || c.is_whitespace())
            .collect();

        let given_anwser: String = answer
            .answer
            .chars()
            .map(remove_accents)
            .filter(|c| c.is_alphanumeric() || c.is_whitespace())
            .collect();

        debug!("given answer: {}", given_anwser);
        debug!("good answer:  {}", good_answer);

        if sublime_fuzzy::best_match(&given_anwser, &good_answer).is_none() {
            return Err(ServerError::NotAcceptable(
                serde_json::to_string(&Message::WrongAnswer).unwrap(),
            ));
        }

        // If so, search the next step...
        let s = steps
            .filter(rank.eq(u.current_step + 1))
            .first::<Step>(&conn)?;
        // ... update the user's step if the step exists...
        diesel::update(users)
            .filter(id.eq(*oid))
            .set(current_step.eq(s.rank))
            .execute(&conn)?;
        // ... and return the step
        Ok(s)
    })
    .await??;
    Ok(HttpResponse::Ok().json(&Message::Success(step)))
}

// Get current step
#[get("/{oid}/current_step")]
pub async fn current_step(
    pool: web::Data<DbPool>,
    oid: web::Path<i32>,
) -> Result<HttpResponse, ServerError> {
    let conn = pool.get()?;
    let step = web::block(move || {
        use crate::schema::steps::dsl::rank;
        use crate::schema::steps::dsl::steps;
        use crate::schema::users::dsl::*;
        // Get the user with that id
        let u = users.find(*oid).first::<User>(&conn)?;
        // ...and respond with his current step
        match steps.filter(rank.eq(u.current_step)).first::<Step>(&conn) {
            Ok(s) => Ok(s),
            Err(e) => Err(e),
        }
    })
    .await??;
    Ok(HttpResponse::Ok().json(step))
}

fn get_dist(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    let part_one: f64 = (90.0 - lat1).to_radians().cos() * (90.0 - lat2).to_radians().cos();
    let part_two: f64 = (90.0 - lat1).to_radians().sin()
        * (90.0 - lat2).to_radians().sin()
        * (lng1 - lng2).to_radians().cos();
    (part_one + part_two).acos() * 6371.0 * 1000.0
}
